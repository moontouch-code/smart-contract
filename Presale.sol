// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./SecurityBase.sol";

contract Presale is SecurityBase   {

    bool        public _open;
    bool        public _whitelistFlag;
    uint        public _cursor;

    mapping(address => uint)    private _stats;
    mapping(string => bool)     private _usedNonces;

    uint constant   public PRICE = 0.005 ether;
    uint constant   public QUANTITY_LIMIT = 1;
    uint constant   public TOTAL_SUPPLY = 2700;

    event Closed(uint timestamp);
    event Open(uint timestamp);
    event Refund(address spender, string nonce , uint refundAmount);
    event Sent(address spender, string nonce, uint amount, uint[] lstNumbers);

    struct Status {
        string state;
        uint totalSupply;
        uint cursor;
    }

    constructor() {
        _cursor = 0;
        _open = false;
        _whitelistFlag = true;
    }

    function open(bool newValue) external onlyMinter {
        if (_open != newValue) {
            _open = newValue;
            if (_open) {
                emit Open(block.timestamp);
            } else {
                emit Closed(block.timestamp);
            }
        }
    }

    function peek(address owner) external view returns(uint) {
        return _stats[owner];
    }

    function setWhitelistFlag(bool newValue) external onlyMinter {
        if (_whitelistFlag != newValue) {
            _whitelistFlag = newValue;    
        }
    }

    function status() external view returns(Status memory) {
        Status memory context;
        context.totalSupply = TOTAL_SUPPLY;
        context.cursor = _cursor;
        if (_cursor >= TOTAL_SUPPLY) {
            context.state = "SELL OUT";
        } else if (!_open) {
            context.state = "COMING SOON";
        } else {
            context.state = "OPEN";
        }
        return context;
    }

    function withdraw(address payable to) external onlyMinter {
        uint balance = address(this).balance;
        if (balance > 0) {
            to.transfer(balance);
        }
    }

    function buy(string memory nonce, bytes calldata signature) external payable {
        require(msg.value == PRICE, "Wrong value");
        require (_open, "Coming soon");
        require(_cursor < TOTAL_SUPPLY, "Sell out");
        require (_whitelistFlag, "Free time");
        require(!_usedNonces[nonce], "Nonce used");

        address spender = _msgSender();
        require(_stats[spender] < QUANTITY_LIMIT, "Out of minted number");
        
        bytes32 signedMessageHash = _getSignedMessageHash(spender, nonce, msg.value);
        address signer = _recoverSigner(signedMessageHash, signature);
        require(super.hasRole(MINTER_ROLE, signer), "Signature is not from minter");

        uint[] memory lstNumbers = new uint[](1);
        lstNumbers[0] = _cursor++;
        _stats[spender]++;
        _usedNonces[nonce] = true;

        emit Sent(spender, nonce, msg.value, lstNumbers);
    }

    function freeBuy(string memory nonce, bytes calldata signature) external payable {
        require(msg.value >= PRICE && msg.value % PRICE == 0, "Wrong value");
        require (_open, "Coming soon");
        require(_cursor < TOTAL_SUPPLY, "Sell out");
        require (!_whitelistFlag, "Whitelist time");
        require(!_usedNonces[nonce], "Nonce used");
        
        address spender = _msgSender();
        bytes32 signedMessageHash = _getSignedMessageHash(spender, nonce, msg.value);
        address signer = _recoverSigner(signedMessageHash, signature);
        require(super.hasRole(MINTER_ROLE, signer), "Signature is not from minter");

        uint cnt = msg.value / PRICE;
        if (_cursor + cnt > TOTAL_SUPPLY) {
            cnt = TOTAL_SUPPLY - _cursor;
        }

        uint[] memory lstNumbers = new uint[](cnt);
        for (uint i=0; i<cnt; i++) {
            lstNumbers[i] = _cursor++;
        }

        _stats[spender] += cnt;
        _usedNonces[nonce] = true;
        emit Sent(spender, nonce, msg.value, lstNumbers);

        uint usedAmount = cnt * PRICE;
        uint refundAmount = msg.value - usedAmount;

        // Refund of remaining
        if (refundAmount > 0) {
            payable(spender).transfer(refundAmount);
            emit Refund(spender, nonce, refundAmount);
        }
    }

    function _getSignedMessageHash(address spender, string memory nonce, uint amount) private pure returns (bytes32) {
        /*
            Signature is produced by signing a keccak256 hash with the following format:
            "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32", 
                keccak256(
                    abi.encode(
                        spender, 
                        nonce, 
                        amount
                    )
                )
            )
        );
    }

    function _recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) private pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function _splitSignature(bytes memory sig) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            /*
                First 32 bytes stores the length of the signature

                add(sig, 32) = pointer of sig + 32
                effectively, skips first 32 bytes of signature

                mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
