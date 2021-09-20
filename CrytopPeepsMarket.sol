pragma solidity ^0.4.8;
contract CryptoPeepsMarket {

    // You can use this hash to verify the image file containing all the Peeps
    string public imageHash = "ac39af4793119ee46bbff351d8cb6b5f23da60222126add4268e261199a2921b";

    address owner;

    string public standard = 'CryptoPeeps';
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    uint public nextPeepsIndexToAssign = 0;

    bool public allPeepsAssigned = false;
    uint public PeepsRemainingToAssign = 0;

    //mapping (address => uint) public addressToPeepsIndex;
    mapping (uint => address) public PeepsIndexToAddress;

    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;

    struct Offer {
        bool isForSale;
        uint PeepsIndex;
        address seller;
        uint minValue;          // in ether
        address onlySellTo;     // specify to sell only to a specific person
    }

    struct Bid {
        bool hasBid;
        uint PeepsIndex;
        address bidder;
        uint value;
    }

    // A record of Peeps that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping (uint => Offer) public PeepsOfferedForSale;

    // A record of the highest Peeps bid
    mapping (uint => Bid) public PeepsBids;

    mapping (address => uint) public pendingWithdrawals;

    event Assign(address indexed to, uint256 PeepsIndex);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event PeepsTransfer(address indexed from, address indexed to, uint256 PeepsIndex);
    event PeepsOffered(uint indexed PeepsIndex, uint minValue, address indexed toAddress);
    event PeepsBidEntered(uint indexed PeepsIndex, uint value, address indexed fromAddress);
    event PeepsBidWithdrawn(uint indexed PeepsIndex, uint value, address indexed fromAddress);
    event PeepsBought(uint indexed PeepsIndex, uint value, address indexed fromAddress, address indexed toAddress);
    event PeepsNoLongerForSale(uint indexed PeepsIndex);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function CryptoPeepssMarket() payable {
        //        balanceOf[msg.sender] = initialSupply;              // Give the creator all initial tokens
        owner = msg.sender;
        totalSupply = 1000;                        // Update total supply
        PeepsRemainingToAssign = totalSupply;
        name = "CRYPTOPEEPS";                                   // Set the name for display purposes
        symbol = "Ͼ";                               // Set the symbol for display purposes
        decimals = 0;                                       // Amount of decimals for display purposes
    }

    function setInitialOwner(address to, uint PeepsIndex) {
        if (msg.sender != owner) throw;
        if (allPeepsAssigned) throw;
        if (PeepsIndex >= 1000) throw;
        if (PeepsIndexToAddress[PeepsIndex] != to) {
            if (PeepsIndexToAddress[PeepsIndex] != 0x0) {
                balanceOf[PeepsIndexToAddress[PeepsIndex]]--;
            } else {
                PeepsRemainingToAssign--;
            }
            PeepsIndexToAddress[PeepsIndex] = to;
            balanceOf[to]++;
            Assign(to, PeepsIndex);
        }
    }

    function setInitialOwners(address[] addresses, uint[] indices) {
        if (msg.sender != owner) throw;
        uint n = addresses.length;
        for (uint i = 0; i < n; i++) {
            setInitialOwner(addresses[i], indices[i]);
        }
    }

    function allInitialOwnersAssigned() {
        if (msg.sender != owner) throw;
        allPeepsAssigned = true;
    }

    function getPeeps(uint PeepsIndex) {
        if (!allPeepsAssigned) throw;
        if (PeepsRemainingToAssign == 0) throw;
        if (PeepsIndexToAddress[PeepsIndex] != 0x0) throw;
        if (PeepsIndex >= 1000) throw;
        PeepsIndexToAddress[PeepsIndex] = msg.sender;
        balanceOf[msg.sender]++;
        PeepsRemainingToAssign--;
        Assign(msg.sender, PeepsIndex);
    }

    // Transfer ownership of a Peeps to another user without requiring payment
    function transferPeeps(address to, uint PeepsIndex) {
        if (!allPeepsAssigned) throw;
        if (PeepsIndexToAddress[PeepsIndex] != msg.sender) throw;
        if (PeepsIndex >= 1000) throw;
        if (PeepsOfferedForSale[PeepsIndex].isForSale) {
            PeepsNoLongerForSale(PeepsIndex);
        }
        PeepsIndexToAddress[PeepsIndex] = to;
        balanceOf[msg.sender]--;
        balanceOf[to]++;
        Transfer(msg.sender, to, 1);
        PeepsTransfer(msg.sender, to, PeepsIndex);
        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid bid = PeepsBids[PeepsIndex];
        if (bid.bidder == to) {
            // Kill bid and refund value
            pendingWithdrawals[to] += bid.value;
            PeepsBids[PeepsIndex] = Bid(false, PeepsIndex, 0x0, 0);
        }
    }
    
   
   

    function offerPeepsForSale(uint PeepsIndex, uint minSalePriceInWei) {
        if (!allPeepsAssigned) throw;
        if (PeepsIndexToAddress[PeepsIndex] != msg.sender) throw;
        if (PeepsIndex >= 1000) throw;
        PeepsOfferedForSale[PeepsIndex] = Offer(true, PeepsIndex, msg.sender, minSalePriceInWei, 0x0);
        PeepsOffered(PeepsIndex, minSalePriceInWei, 0x0);
    }

    function offerPeepsForSaleToAddress(uint PeepsIndex, uint minSalePriceInWei, address toAddress) {
        if (!allPeepsAssigned) throw;
        if (PeepsIndexToAddress[PeepsIndex] != msg.sender) throw;
        if (PeepsIndex >= 1000) throw;
        PeepsOfferedForSale[PeepsIndex] = Offer(true, PeepsIndex, msg.sender, minSalePriceInWei, toAddress);
        PeepsOffered(PeepsIndex, minSalePriceInWei, toAddress);
    }

    function buyPeeps(uint PeepsIndex) payable {
        if (!allPeepsAssigned) throw;
        Offer offer = PeepsOfferedForSale[PeepsIndex];
        if (PeepsIndex >= 1000) throw;
        if (!offer.isForSale) throw;                // Peeps not actually for sale
        if (offer.onlySellTo != 0x0 && offer.onlySellTo != msg.sender) throw;  // Peeps not supposed to be sold to this user
        if (msg.value < offer.minValue) throw;      // Didn't send enough ETH
        if (offer.seller != PeepsIndexToAddress[PeepsIndex]) throw; // Seller no longer owner of Peeps
        address seller = offer.seller;

        PeepsIndexToAddress[PeepsIndex] = msg.sender;
        balanceOf[seller]--;
        balanceOf[msg.sender]++;
        Transfer(seller, msg.sender, 1);

        PeepsNoLongerForSale(PeepsIndex);
        pendingWithdrawals[seller] += msg.value;
        PeepsBought(PeepsIndex, msg.value, seller, msg.sender);

        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid bid = PeepsBids[PeepsIndex];
        if (bid.bidder == msg.sender) {
            // Kill bid and refund value
            pendingWithdrawals[msg.sender] += bid.value;
            PeepsBids[PeepsIndex] = Bid(false, PeepsIndex, 0x0, 0);
        }
    }

    function withdraw() {
        if (!allPeepsAssigned) throw;
        uint amount = pendingWithdrawals[msg.sender];
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        pendingWithdrawals[msg.sender] = 0;
        
    }

    function enterBidForPeeps(uint PeepsIndex) payable {
        if (PeepsIndex >= 1000) throw;
        if (!allPeepsAssigned) throw;                
        if (PeepsIndexToAddress[PeepsIndex] == 0x0) throw;
        if (PeepsIndexToAddress[PeepsIndex] == msg.sender) throw;
        if (msg.value == 0) throw;
        Bid existing = PeepsBids[PeepsIndex];
        if (msg.value <= existing.value) throw;
        if (existing.value > 0) {
            // Refund the failing bid
            pendingWithdrawals[existing.bidder] += existing.value;
        }
        PeepsBids[PeepsIndex] = Bid(true, PeepsIndex, msg.sender, msg.value);
        PeepsBidEntered(PeepsIndex, msg.value, msg.sender);
    }

    function acceptBidForPeeps(uint PeepsIndex, uint minPrice) {
        if (PeepsIndex >= 1000) throw;
        if (!allPeepsAssigned) throw;                
        if (PeepsIndexToAddress[PeepsIndex] != msg.sender) throw;
        address seller = msg.sender;
        Bid bid = PeepsBids[PeepsIndex];
        if (bid.value == 0) throw;
        if (bid.value < minPrice) throw;

        PeepsIndexToAddress[PeepsIndex] = bid.bidder;
        balanceOf[seller]--;
        balanceOf[bid.bidder]++;
        Transfer(seller, bid.bidder, 1);

        PeepsOfferedForSale[PeepsIndex] = Offer(false, PeepsIndex, bid.bidder, 0, 0x0);
        uint amount = bid.value;
        PeepsBids[PeepsIndex] = Bid(false, PeepsIndex, 0x0, 0);
        pendingWithdrawals[seller] += amount;
        PeepsBought(PeepsIndex, bid.value, seller, bid.bidder);
    }

    function withdrawBidForPeeps(uint PeepsIndex) {
        if (PeepsIndex >= 1000) throw;
        if (!allPeepsAssigned) throw;                
        if (PeepsIndexToAddress[PeepsIndex] == 0x0) throw;
        if (PeepsIndexToAddress[PeepsIndex] == msg.sender) throw;
        Bid bid = PeepsBids[PeepsIndex];
        if (bid.bidder != msg.sender) throw;
        PeepsBidWithdrawn(PeepsIndex, bid.value, msg.sender);
        uint amount = bid.value;
        PeepsBids[PeepsIndex] = Bid(false, PeepsIndex, 0x0, 0);
        // Refund the bid money
  
    }

}
