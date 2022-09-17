// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/TrueYield.sol";

contract TrueYieldTest is Test {
    TrueYield public trueYield;

    address owner = address(0x1234);
    address userOne = address(0x1122);
    address deployer;

    //Setup Function
    //Owner deployed the contract
    function setUp() public {
        vm.startPrank(owner);
        trueYield = new TrueYield();
        deployer = owner;
        vm.stopPrank();
    }

    //Deployer is the owner (TEST-1)
    function testOwner() public {
        assertEq(deployer, address(0x1234));
    }

    //Current Position Id is 0 when contract is deployed (TEST-2)
    function testCurrentPositionId() public {
        assertEq(trueYield.currentPositionId(), 0);
    }

    //Tiers have been updated when contract is deployed (TEST-3)
    function testTiers() public {
        assertEq(trueYield.tiers(30), 700);
    }

    //LockPeriods array has been populated when contract is deployed (TEST-4)
    function testLockPeriods() public {
        assertEq(uint(trueYield.getLockPeriods().length), 3);
    }

    //Test if the stakerEther function works correctly (TEST-5)
    function testStakeEther() public {
        uint initialContractBalance = address(trueYield).balance;

        vm.startPrank(userOne);
        vm.deal(userOne, 1 ether);

        trueYield.stakeEther{value: 0.5 ether}(30);

        uint currentContractBalance = address(trueYield).balance;

        //positionId will be 0 for the first position because currentPositionId gets updated after position gets updated
        assertEq(trueYield.getPositionById(0).positionId, 0);
        //The array mapping should have an entry for the staked position
        assertEq(trueYield.getAllPositionIdsByAddress(userOne).length, 1);
        //Contract balance should increase by the amount user has staked
        assertEq(currentContractBalance, initialContractBalance + 0.5 ether);

        vm.stopPrank();
    }

    //Test if the calculateInterest function calculates the interest correctly (TEST-6)
    function testCalculateInterest() public {
        uint calculated = trueYield.calculateInterest(700, 30, 1000000000000000000);
        assertEq(calculated, 70000000000000000);
    }

    //Test if the owner can change unlock date correctly (TEST-7)
    function testChangeUnlockDate() public {
        vm.startPrank(owner);
        trueYield.changeUnlockDate(1, 1663437715);
        assertEq(trueYield.getPositionById(1).unlockDate, 1663437715);
        vm.stopPrank();
    }

    //Test if the user gets 0 interest if he closes position before the unlock date (TEST-8)
    function testCloseBeforeUnlock() public {

        vm.startPrank(userOne);

        vm.deal(userOne, 1 ether);

        trueYield.stakeEther{value: 0.5 ether}(30);

        assertEq(trueYield.getPositionById(0).weiStaked, 500000000000000000);

        assertEq(address(userOne).balance, 0.5 ether);

        uint balanceBefore = address(userOne).balance;

        trueYield.closePosition(0);

        uint balanceAfter = address(userOne).balance;

        assertEq(balanceAfter, trueYield.getPositionById(0).weiStaked + balanceBefore);
        vm.stopPrank();
    }

    //Test if the user earn the right amount of interest if he closes position after the unlock date (TEST-9)
    function testCloseAfterUnlock() public {
        //First stake the amount from userOne
        vm.startPrank(userOne);
        vm.deal(userOne, 1 ether);
        trueYield.stakeEther{value: 0.5 ether}(30);
        assertEq(trueYield.getPositionById(0).weiStaked, 500000000000000000);
        assertEq(address(userOne).balance, 0.5 ether);
        vm.stopPrank();

        //Fund the contract with some Ethers otherwise it won't be able to pay Interest
        vm.deal(address(trueYield), 20 ether);
        assertGt(address(trueYield).balance, 19 ether);

        //Then fund the contract and change the unlock date of the created position to a previous date
        vm.startPrank(owner);
        //Set the unlockDate timestamp to Zero otherwise block.timeStamp will not be greater than unlockDate
        trueYield.changeUnlockDate(0, 0);
        assertEq(trueYield.getPositionById(0).unlockDate, 0);
        vm.stopPrank();

        //The close the position from userOne and check if the user earns the interest after closing

        vm.startPrank(userOne);
        uint balanceBefore = address(userOne).balance;
        trueYield.closePosition(0);
        uint balanceAfter = address(userOne).balance;

        assertGt(block.timestamp, trueYield.getPositionById(0).unlockDate);
        assertEq(balanceAfter, trueYield.getPositionById(0).weiStaked + balanceBefore + trueYield.getPositionById(0).weiInterest);
        vm.stopPrank();
    }

}