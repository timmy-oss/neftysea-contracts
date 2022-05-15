# @title Accountant  Smart Contract, Keeps money in the interim untils transactions are confirmed on the NFTs

event Deposit:
    payer : address
    beneficiary : address
    value : uint256


event Withdrawal:
    payer : address
    beneficiary : address
    value : uint256


struct Payment:
    value : uint256
    withdrawn : bool
    recalled : bool
    payer : address
    beneficiary : address
    

# State Variables 
ledger : public(HashMap[address, HashMap[address, HashMap[uint256, Payment]]])
admins : HashMap[address, bool]
wallet : address
pause  : bool





@external
def __init__():
    self.admins[msg.sender] = True
    self.wallet = msg.sender
    self.pause = False


@internal
def _isAdmin( _admin  :address) -> bool:
    return self.admins[_admin]

@external
def pauseAll():
    assert self._isAdmin(msg.sender)
    assert not self.pause

    self.pause  = True



@external
def unPauseAll():
    assert self._isAdmin(msg.sender)
    assert  self.pause

    self.pause  = False


@external
def changeWallet( _newWallet  : address):
    assert not self.pause

    assert self._isAdmin(msg.sender)
    assert _newWallet != ZERO_ADDRESS

    self.wallet = _newWallet

@external
def makeAdmin( _user : address) -> bool :
    assert not self.pause

    assert self._isAdmin(msg.sender)
    assert _user != ZERO_ADDRESS
    
    if( self._isAdmin(_user)):
        return True

    self.admins[_user] = True
    return self._isAdmin(_user)

@external
def removeAdmin( _admin : address) -> bool:
    assert not self.pause

    assert self._isAdmin(msg.sender)
    assert _admin != ZERO_ADDRESS
    assert msg.sender != _admin
    assert self._isAdmin(_admin)

    self.admins[_admin] = False
    return not (self._isAdmin(_admin))

    

@external
def withdraw( _payer : address, _beneficiary : address,  _paymentId : uint256  ):
    assert not self.pause
    assert self._isAdmin(msg.sender), "Only admins"
    assert _paymentId != empty(uint256), 'Invalid payment ID'
    assert _payer != ZERO_ADDRESS
    assert _beneficiary != ZERO_ADDRESS

    payment : Payment = ((self.ledger[_payer])[_beneficiary])[_paymentId]
    assert payment.payer != ZERO_ADDRESS, 'Invalid retrieval references - payer'
    assert payment.beneficiary != ZERO_ADDRESS, 'Invalid retrieval references - beneficiary'
    assert not payment.withdrawn, 'Payment retrieved already'
    assert not payment.recalled, 'Payment recalled'
    assert payment.value > 0, 'Amount to pay must be greater than zero'
    assert self.balance >= payment.value, 'Contract is low on balance'
    
    ((self.ledger[_payer])[_beneficiary])[_paymentId].withdrawn = True
    send( _beneficiary, payment.value)
    log Withdrawal(_payer, _beneficiary, payment.value)





@external
def recall( _beneficiary : address, _paymentId : uint256):
    assert not self.pause

    assert _beneficiary != ZERO_ADDRESS
    assert _paymentId != empty(uint256)
    payment : Payment = ((self.ledger[msg.sender])[_beneficiary])[_paymentId]
    assert payment.payer != ZERO_ADDRESS,  'Invalid references'
    assert payment.beneficiary != ZERO_ADDRESS,  'Invalid references'
    assert payment.value > 0, 'Amount to pay must be greater than zero'
    assert not payment.withdrawn, 'Payment retrieved already'
    assert not payment.recalled, 'Payment recalled'
    
    payment.recalled = True
    ((self.ledger[msg.sender])[_beneficiary])[_paymentId] = payment

    send(msg.sender, payment.value)




@external
@payable
def deposit(  _beneficiary : address, _paymentId : uint256, _charges : uint256):
    assert not self.pause

    assert msg.value > 0, 'Value must be more than 0'
    assert _charges >= 0, "Charges must not be less than zero" 
    assert msg.value > _charges, 'Value must be greater than charges'
    assert _beneficiary != ZERO_ADDRESS
    assert _paymentId != empty(uint256)
    payment : Payment =  ((self.ledger[msg.sender])[_beneficiary])[_paymentId] 
    assert payment.payer == ZERO_ADDRESS,  'Invalid references'
    assert payment.beneficiary == ZERO_ADDRESS,  'Invalid references'
    assert payment.value == 0, 'Invalid references'

    
    remittance : uint256 = msg.value - _charges

    send(self.wallet, _charges)

    newPayment : Payment = Payment({
        value : remittance,
        withdrawn : False,
        recalled : False,
        payer : msg.sender,
        beneficiary : _beneficiary
        
    })
    ((self.ledger[msg.sender])[_beneficiary])[_paymentId] = newPayment
    log Deposit( msg.sender, _beneficiary, msg.value)


    


