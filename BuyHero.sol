// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


import "./IAccessor.sol";
import "./IRandomizer.sol";
import "./IGenerator.sol";
import "./SecurityBase.sol";


interface IToken {
    function balanceOf(address to) external returns (uint);
    function allowance(address owner, address spender) external returns (uint);
    function transferFrom(address owner, address to, uint amount) external;
}

contract BuyHero is SecurityBase {
    uint public quantity;
    uint public batchLimit;
    uint public keepalive;
    uint public offset;

    IAccessor public accessor;
    IGenerator public generator;
    IRandomizer public randomizer;

    address public receiver;

    mapping(bytes => bool) private _usedSignatures;
    mapping(address => bool) private _supportedTokens;

    constructor() {
        quantity    = 10000;
        batchLimit  = 10;
        keepalive   = 1*60*60;
        offset      = 3*60;
    }

    function setAccessor(address newValue)
        external 
        onlyMinter
    {
        accessor = IAccessor(newValue);
    }

    function setGenerator(address newValue)
        external
        onlyMinter
    {
        generator = IGenerator(newValue);
    }

    function setRandomizer(address newValue)
        external
        onlyMinter
    {
        randomizer = IRandomizer(newValue);
    }
    
    function setReceiver(address newValue)
        external 
        onlyMinter
    {
        receiver = newValue;
    }

    function registerToken(address newValue)
        external
        onlyMinter
    {
        _supportedTokens[newValue] = true;
    }

    function unregisterToken(address newValue)
        external
        onlyMinter
    {
        _supportedTokens[newValue] = false;
    }

    function setBatchLimit(uint newValue)
        external 
        onlyMinter
    {
        require(newValue > 1, "BuyHero: failed to set batch limit");
        batchLimit = newValue;
    }

    function setKeepalive(uint newValue)
        external
        onlyMinter
    {
        require(newValue > 1*60, "BuyHero: failed to set signature keepalive");
        keepalive = newValue;
    }
    
    function setOffset(uint newValue)
        external 
        onlyMinter
    {
        require(newValue > 1*60, "BuyHero: failed to set timestamp offset");
        offset = newValue;
    }

    function sell(uint256 amount, address currency, uint price, uint timestamp, uint chainId, bytes calldata signature) 
        public
        whenNotPaused
    {
        require(amount <= batchLimit, "BuyHero: amount too many");
        require(chainId == block.chainid, "BuyHero: invalid chain id");
        require(
            timestamp + keepalive > block.timestamp && 
            timestamp < block.timestamp+offset, 
            "BuyHero: signature is overtime"
        );
        require(!_usedSignatures[signature], "BuyHero: signature used.");
        require(_supportedTokens[currency], "BuyHero: disallowed currency token");

        bytes32 messageHash = getMessageHash(amount, currency, price, timestamp, chainId);
        bytes32 signedMessageHash = getEthSignedMessageHash(messageHash);
        require(
            accessor.hasRole(
                keccak256("MINTER_ROLE"), 
                recoverSigner(signedMessageHash, signature)
            ), 
            "BuyHero: signature is not from minter"
        );

        _sell(currency, amount, price, _saltGen(signature));
        _usedSignatures[signature] = true;
    }

    function _saltGen(bytes memory signature)
        private 
        view 
        returns(uint)
    {
        return uint(
            keccak256(
                abi.encodePacked(
                    block.number,
                    block.timestamp,
                    block.coinbase,
                    signature
                )
            )
        );
    }

    function _sell(address token, uint amount, uint price, uint salt) private {
        // Pay the fee.
        require(_supportedTokens[token], "BuyHero: disallowed token");
        IToken(token).transferFrom(_msgSender(), receiver, amount*price);

        // Minting heroes for the msg.sender 
        _mint(_msgSender(), amount, salt);
    }

    function _mint(address to, uint amount, uint salt) private {
        require(amount <= quantity, "BuyHero: sell out");

        // Generate random seed.
        uint seed = randomizer.rand(salt, 0, to) % 10000000;

        // Generate DNA list of heroes.
        string[] memory res = new string[](amount);
        for (uint i = 0; i < amount; i++) {
            res[i] = generator.spawn(seed);
        }

        // Minting heroes for the msg.sender 
        accessor.mintBatch(to, amount, res);
        quantity = quantity - amount;
    }

    function getMessageHash(uint amount, address currency, uint price, uint timestamp, uint chainId)
        private 
        pure 
        returns (bytes32)
    {
        return keccak256(abi.encode(amount, currency, price, timestamp, chainId));
    }

    function getEthSignedMessageHash(bytes32 _messageHash)
        private
        pure
        returns (bytes32)
    {
        /*
            Signature is produced by signing a keccak256 hash with the following format:
            "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }
    
    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) 
        private 
        pure 
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        private
        pure
        returns (bytes32 r, bytes32 s, uint8 v)
    {
        require(sig.length == 65, "BuyHero: invalid signature length");

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