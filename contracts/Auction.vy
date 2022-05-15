# @title Auction  contract for bidding of NFTs


# State Variables 

beneficiary : public(address)
highestBidder : public(address)
highestBid : public(uint256)
biddingStarts : public( uint256)
biddingEnds : public(uint256)
nft : public(uint256)
minimumBid : public(uint256)
bids : public(HashMap[address, uint256])
numberOfBidders : public(uint256)
returns : HashMap[address, uint256]
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
def __init__(  _biddingStarts : uint256, _biddingTime : uint256, _nft : uint256, _minimumBid : uint256):
    self.beneficiary = msg.sender

    # Checks
    assert _biddingStarts >= block.timestamp, 'Bidding must start now or in the future'
    assert  _biddingStarts + _biddingTime > block.timestamp, 'Bidding must end in the future'
    assert _minimumBid > 0, 'Minimum bid cannot be zero'


    self.biddingStarts = _biddingStarts
    self.biddingEnds = _biddingStarts + _biddingTime
    self.minimumBid = _minimumBid
    self.nft = _nft
    self.numberOfBidders = 0


@external
@payable
def bid():
    assert block.timestamp >= self.biddingStarts, 'Bidding is yet to start'
    assert self.biddingEnds > block.timestamp, 'Bidding has ended'
    assert msg.sender != self.beneficiary
    assert msg.value >= self.minimumBid , 'Bid less than minimum bid'
    assert self.bids[msg.sender] + msg.value > self.highestBid, 'Total bid less than highest bid'

    if(self.bids[msg.sender] == empty(uint256)):
        self.numberOfBidders += 1

    self.bids[msg.sender] += msg.value

    self.returns[msg.sender] = empty(uint256)
    self.returns[self.highestBidder] = self.highestBid

    self.highestBid = self.bids[msg.sender]
    self.highestBidder  =msg.sender
        

    log Bid( msg.sender, self.bids[msg.sender])

@external
@view
def getBalance() -> uint256:
    assert self.beneficiary == msg.sender, 'Only beneficiary can call'
    return self.balance



@external
def endBid():
    assert msg.sender == self.beneficiary
    assert block.timestamp > self.biddingEnds, 'Bidding has not ended'
    assert self.numberOfBidders > 1, 'No bids recorded'
    assert self.winner == ZERO_ADDRESS, 'Beneficiary paid already'

    self.winner = self.highestBidder
    #Transfer Token Here
    self.returns[self.winner]   = empty(uint256)
    send( self.beneficiary, self.highestBid )

    if( self.winner != ZERO_ADDRESS and ((self.numberOfBidders - self.numberOfRefundsMade) == 1)):
        selfdestruct(self.beneficiary)


@external
def getRefund():
    assert block.timestamp > self.biddingEnds, 'Bidding has not ended'
    assert self.returns[msg.sender] > 0, 'You have no refund in this auction'

    refund : uint256 = self.returns[msg.sender]

    self.returns[msg.sender] = empty(uint256)
    self.numberOfRefundsMade += 1
    send(msg.sender, refund)

    log Refund(msg.sender, refund)

    if( self.winner != ZERO_ADDRESS and ((self.numberOfBidders - self.numberOfRefundsMade) == 1)):
        selfdestruct(self.beneficiary)


    





    








    

