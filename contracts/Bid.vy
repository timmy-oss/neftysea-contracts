# @title Auction  contract for bidding of NFTs


# State Variables 

beneficiary : public(address)
nft : public(uint256)
minimumBid : public(uint256)
bids : public(HashMap[address, uint256])
numberOfBidders : public(uint256)
winner : public(address)
numberOfRefundsMade : public(uint256)

# Events

event Bid:
    bidder : address
    amount : uint256


event Refund:
    bidder  : address
    amount : uint256



# Functions 

@external
def __init__(   _nft : uint256):
    self.beneficiary = msg.sender
    self.nft = _nft
    self.numberOfBidders = 0


@external
@payable
def bid():
  
    assert msg.sender != self.beneficiary
   

    if(self.bids[msg.sender] == empty(uint256)):
        self.numberOfBidders += 1

    self.bids[msg.sender] += msg.value


    log Bid( msg.sender, self.bids[msg.sender])

@external
@view
def getBalance() -> uint256:
    assert self.beneficiary == msg.sender, 'Only beneficiary can call'
    return self.balance



@external
def endBid(_chosenBidder : address):
    assert msg.sender == self.beneficiary
    assert _chosenBidder != ZERO_ADDRESS
    assert _chosenBidder != self.beneficiary
   
    assert self.numberOfBidders > 0, 'No bids recorded'
    assert self.winner == ZERO_ADDRESS, 'Beneficiary paid already'

    self.winner = _chosenBidder
    #Transfer Token Here
    bidAmount : uint256 = self.bids[_chosenBidder]
    self.bids[_chosenBidder] = empty(uint256)
    send( self.beneficiary, bidAmount )

    if( self.winner != ZERO_ADDRESS and ((self.numberOfBidders - self.numberOfRefundsMade) == 1)):
        selfdestruct(self.beneficiary)


@external
def getRefund():
    
    assert self.bids[msg.sender] > 0, 'You have no refund in this auction'

    refund : uint256 = self.bids[msg.sender]

    self.bids[msg.sender] = empty(uint256)
    self.numberOfRefundsMade += 1
    send(msg.sender, refund)

    log Refund(msg.sender, refund)

    if( self.winner != ZERO_ADDRESS and ((self.numberOfBidders - self.numberOfRefundsMade) == 1)):
        selfdestruct(self.beneficiary)


    





    








    

