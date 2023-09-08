// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "./SecurityBase.sol";


// MTH: Moon touch honour
contract MTH is ERC20, ERC20Pausable, ERC20Burnable, SecurityBase {
    string  constant TOKEN_NAME           = "Moon Touch Honour";
    string  constant TOKEN_SYMBOL         = "MTH";
    uint256 constant TOKEN_INITIAL_SUPPLY = 10*100000000;
    
    mapping (address => bool) private _isBlackListed;

    event AddedBlackList(address[] list);
    event RemovedBlackList(address[] list);

    event TransferEx(address from, address to, uint256 value);
    event Paid(address from, address to, uint256 value, string action);

    constructor() ERC20(TOKEN_NAME, TOKEN_SYMBOL) {
        uint _totalSupply = TOKEN_INITIAL_SUPPLY * (10 ** decimals());
        _mint(_msgSender(), _totalSupply);
    }

    function mint(address, uint256) external view onlyMinter {
        revert("MTH: minting is not allowed");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override (ERC20, ERC20Pausable) {
        require(!_isBlackListed[from], "MTH: from is blacklisted");

        super._beforeTokenTransfer(from, to, amount);
    }
    
    function _transfer(address from, address to, uint256 amount) internal override {
        super._transfer(from, to, amount);
        emit TransferEx(from, to, amount);
    }

    function isBlackListed(address _user) external view returns (bool) {
        return _isBlackListed[_user];
    }

    function addBlackList (address[] calldata _userList) external onlyMinter {
        require(_userList.length > 0, "MTH: bad request");
        for (uint i=0; i<_userList.length; i++) {
            _isBlackListed[_userList[i]] = true;
        }
        emit AddedBlackList(_userList);
    }

    function removeBlackList (address[] calldata _userList) external onlyMinter {
        require(_userList.length > 0, "MTH: bad request");
        for (uint i=0; i<_userList.length; i++) {
            _isBlackListed[_userList[i]] = false;
        }
        emit RemovedBlackList(_userList);
    }

    function pay(address to, uint256 amount, string memory action) external {
        address owner = _msgSender();
        super._transfer(owner, to, amount);
        emit Paid(owner, to, amount, action);
    }
}