pragma solidity ^0.8.20;

contract VulnerableVault {
    address public owner;
    uint256 public stored;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Users can deposit ETH
    function deposit() external payable {
        require(msg.value > 0, "no ETH sent");
    }

    // Returns how much ETH is in the vault
    function balance() external view returns (uint256) {
        return address(this).balance;
    }

    // Anyone can withdraw all funds — NO access control!
    function withdrawAll(address payable to) public {
        to.transfer(address(this).balance);
    }

    receive() external payable { }
}
