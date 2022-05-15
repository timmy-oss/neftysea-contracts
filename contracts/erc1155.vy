# @title ERC1155 Smart Contract for NeftySea Maketplace
# @dev This Contracts supports the multi-token starndard and  minimizes gas costs on a large scale



interface ERC1155Receiver:
    def onERC1155Received(_operator : address, _from : address, _id : uint256, _value : uint256,  _data : Bytes[1024]) -> bytes32:view
    def onERC1155BatchReceived( _operator : address, _from   :address, _ids : DynArray[uint256, 1000000], _values : DynArray[uint256, 1000000],  _data : Bytes[1024] ) -> bytes32:view


balances : HashMap[ uint256, HashMap[ address, uint256 ] ]
ownerToOperators : HashMap[address, HashMap[address, bool]]
minter   : address
name : constant(String[16]) = 'NeftySea ERC1155'
tokenIdsToAppprovals : HashMap[uint256, address]
uri : public(HashMap[uint256, String[256]])
admins : HashMap[address,bool]
pause : bool


SUPPORTED_INTERFACES: constant(bytes4[3]) = [
    # ERC165 interface ID of ERC165
    0x01ffc9a7,
    # ERC165 interface ID of ERC721
    0x80ac58cd,

    #METADATA URI SUPPORT ,
    0x0e89341c

]



# Events 
event TransferSingle:
    _operator : indexed(address)
    _from : indexed(address)
    _to  :indexed(address)
    _id : uint256
    _value : uint256


event TransferBatch:
    _operator : indexed(address)
    _from : indexed(address)
    _to : indexed(address)
    _ids : DynArray[uint256, 1000000]
    _values : DynArray[uint256, 1000000]


event ApprovalForAll:
    _owner : indexed(address)
    _operator  :indexed(address)
    _approved : bool


event URI:
    _value : String[256]
    _id : uint256







@external
def __init__():
    self.minter = msg.sender
    self.pause = False


@view
@external
def supportsInterface( interface_id: bytes4) -> bool  :
    return interface_id in SUPPORTED_INTERFACES



@view
@external
def balanceOf(  _owner : address,  _id : uint256) -> uint256 :
    assert _owner != ZERO_ADDRESS
    assert _id != empty(uint256)

    return self.balances[_id][_owner]


@view
@external
def balanceOfBatch( _owners  :DynArray[address, 1000000], _ids  : DynArray[ uint256, 1000000]   ) -> DynArray[uint256, 1000000] :
    assert  len(_owners) ==  len(_ids), "Owners and Ids must be of the same length"
    assert len(_owners) <= 1000000, 'Max. allowed array length is 1000000'

    balances : DynArray[uint256, 1000000] = []
    for i in range(1000000):
        account : address = _owners[i]
        id : uint256 = _ids[i]

        if account == ZERO_ADDRESS or id == empty(uint256):
            break
        else:
            balances.append( self.balances[id][account] )

    return balances


@external  
def setApprovalForAll( _operator : address, _approved : bool):
    assert not self.pause

    assert _operator != ZERO_ADDRESS
    assert _operator != msg.sender, 'Owner cannot be an operator'

    self.ownerToOperators[msg.sender][_operator] =_approved
    log ApprovalForAll( msg.sender, _operator, _approved)





@view 
@internal
def _isApprovedForAll(_owner  :address, _operator : address ) -> bool :
    return self.ownerToOperators[_owner][_operator]



@view 
@external
def isApprovedForAll(_owner  :address, _operator : address ) -> bool :
    return self._isApprovedForAll(_owner, _operator)




# INTERNAL HELPERS

@internal
def _addTokenAmountTo( _to : address, _tokenId : uint256, _amount : uint256):
    assert _to != ZERO_ADDRESS
    assert _amount != 0
    
    self.balances[_tokenId][_to] += _amount 


@internal
def _removeTokenAmountFrom( _from : address, _tokenId : uint256, _amount : uint256):
    assert _from != ZERO_ADDRESS
    assert _amount != 0
    
    self.balances[_tokenId][_from] -= _amount   


@view
@internal
def _hasUpToAmount( _owner : address, _tokenId : uint256, _amount : uint256) -> bool:
    ownerBalance : uint256 =  self.balances[_tokenId][_owner] 
    return ownerBalance>= _amount



@internal
def _transferFrom(_from: address, _to: address, _id: uint256, _amount  :uint256, _sender: address):
    
    assert _to != ZERO_ADDRESS
    assert ( _from == _sender) or (  self._isApprovedForAll( _sender, _from ) ), 'You have no permission to transfer '
    assert self._hasUpToAmount( _from , _id, _amount), 'You do not have enough of this token to transfer '

    self._removeTokenAmountFrom(_from, _id, _amount)
    self._addTokenAmountTo(_to, _id, _amount)





@external
def safeTransferFrom( _from : address, _to : address, _id : uint256,  _amount : uint256, _data : Bytes[1024]=b""):
    assert not self.pause

    self._transferFrom( _from, _to, _id, _amount, msg.sender)
    log TransferSingle( msg.sender, _from , _to, _id, _amount)

    if _to.is_contract :
        returnValue: bytes32 = ERC1155Receiver(_to).onERC1155Received(msg.sender, _from, _id, _amount, _data)
        assert returnValue == method_id("onERC1155Received(address,address,uint256,uint256,bytes)", output_type=bytes32)


@external
def safeBatchTransferFrom( _from : address, _to : address, _ids : DynArray[ uint256, 1000000],  _amounts :DynArray[uint256, 1000000], _data : Bytes[1024]=b""):
    assert not self.pause

    assert  len(_ids) ==  len(_amounts), "Amounts and Ids must be of the same length"
    assert len(_ids) <= 1000000, 'Max. allowed array length is 1000000'

    usedIds :  DynArray[uint256, 1000000] = []
    usedAmounts : DynArray[uint256, 1000000] = []

    for i in range(1000000):
        id : uint256 = _ids[i]
        amount : uint256 = _amounts[i]

        if id == empty(uint256) or amount == empty(uint256):
            break
        else:
            self._transferFrom( _from, _to, id, amount, msg.sender )
            usedIds.append(id)
            usedAmounts.append(amount)

    log TransferBatch( msg.sender, _from, _to, usedIds, usedAmounts )

    if _to.is_contract :
        returnValue: bytes32 = ERC1155Receiver(_to).onERC1155BatchReceived(msg.sender, _from, _ids, _amounts, _data)
        assert returnValue == method_id("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)", output_type=bytes32)



    


# Mint Functions



@internal
def _burn( _account  :address, _id : uint256,  _amount : uint256, _sender : address ):
    assert _account != ZERO_ADDRESS
    assert ( _account == _sender) or (  self._isApprovedForAll(  _account, _sender) ), 'You have no permission to burn'
    assert self._hasUpToAmount( _account, _id, _amount), "You do have have enough token to burn"
    self._removeTokenAmountFrom( _account, _id, _amount)

  


@internal
def _mint( _to  :address, _id : uint256,  _amount : uint256,  _uri : String[256], _sender : address ):
    assert _to != ZERO_ADDRESS
    assert _to == _sender, 'You can only mint for yourself'

    self._addTokenAmountTo( _to, _id, _amount)
    self.uri[_id] = _uri

    if not (self.ownerToOperators[_sender])[ self.minter]:
        self.ownerToOperators[_sender][self.minter] = True



@external
def mint( _to : address, _id : uint256, _amount : uint256,  _uri : String[256],  _data : Bytes[1024]=b"" ):
    assert not self.pause

    self._mint( _to, _id, _amount, _uri, msg.sender )

    log TransferSingle(msg.sender, ZERO_ADDRESS, _to, _id, _amount)

    if _to.is_contract :
        returnValue: bytes32 = ERC1155Receiver(_to).onERC1155Received(msg.sender, ZERO_ADDRESS , _id, _amount, _data)
        assert returnValue == method_id("onERC1155Received(address,address,uint256,uint256,bytes)", output_type=bytes32)


@external
def mintBatch( _to : address, _ids :DynArray[ uint256, 1000000],  _amounts : DynArray [uint256, 1000000],  _uri : String[256],  _data : Bytes[1024]=b"" ):
    assert not self.pause

    assert  len(_ids) ==  len(_amounts), "Amounts and Ids must be of the same length"
    assert len(_ids) <= 1000000, 'Max. allowed array length is 1000000'

    usedIds :  DynArray[uint256, 1000000] = []
    usedAmounts : DynArray[uint256, 1000000] = []

    for i in range(1000000):
        id : uint256 = _ids[i]
        amount : uint256 = _amounts[i]

        if id == empty(uint256) or amount == empty(uint256):
            break
        else:
            self._mint(  _to, id, amount, _uri,  msg.sender )
            usedIds.append(id)
            usedAmounts.append(amount)

    log TransferBatch( msg.sender, ZERO_ADDRESS, _to, usedIds, usedAmounts)

    if _to.is_contract :
        returnValue: bytes32 = ERC1155Receiver(_to).onERC1155BatchReceived(msg.sender, ZERO_ADDRESS, _ids, _amounts, _data)
        assert returnValue == method_id("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)", output_type=bytes32)





@external
def burn( _account : address, _id : uint256, _amount : uint256):
    assert not self.pause

    self._burn( _account, _id, _amount, msg.sender )

    log TransferSingle( msg.sender , _account, ZERO_ADDRESS, _id, _amount)





@external
def burnBatch( _account : address, _ids :DynArray[ uint256, 1000000],  _amounts : DynArray [uint256, 1000000]):
    assert not self.pause

    assert  len(_ids) ==  len(_amounts), "Amounts and Ids must be of the same length"
    assert len(_ids) <= 1000000, 'Max. allowed array length is 1000000'

    usedIds :  DynArray[uint256, 1000000] = []
    usedAmounts : DynArray[uint256, 1000000] = []

    for i in range(1000000):
        id : uint256 = _ids[i]
        amount : uint256 = _amounts[i]

        if id == empty(uint256) or amount == empty(uint256):
            break
        else:
            self._burn(  _account, id, amount,   msg.sender )
            usedIds.append(id)
            usedAmounts.append(amount)

    log TransferBatch( msg.sender, _account, ZERO_ADDRESS, usedIds, usedAmounts)



@external
def pauseAll():
    assert not self.pause
    assert self.minter == msg.sender or self.admins[msg.sender]
    self.pause = True


@external
def unPauseAll():
    assert self.pause
    assert self.minter == msg.sender or self.admins[msg.sender]
    self.pause = False


@external
def addAdmin( _admin : address ):
    assert not self.pause

    assert self.minter == msg.sender or self.admins[msg.sender]
    assert _admin != ZERO_ADDRESS
    self.admins[_admin] = True






  






   





