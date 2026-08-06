// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";

import { DiscoveryBox } from "../src/DiscoveryBox.sol";
import { OpenableERC20 } from "../src/openable/OpenableERC20.sol";

contract DiscoveryBoxTest is Test {
    DiscoveryBox internal box;
    address internal alice = makeAddr("alice");

    function setUp() public {
        box = new DiscoveryBox(address(this));
        assertTrue(box.transfer(alice, 10 ether));
    }

    function test_constructorCreatesFixedSupply() public view {
        assertEq(box.name(), "Discovery Box");
        assertEq(box.symbol(), "BOX");
        assertEq(box.totalSupply(), 100 ether);
        assertEq(box.balanceOf(address(this)), 90 ether);
        assertEq(box.balanceOf(alice), 10 ether);
        assertEq(box.MATURITY_TARGET(), 40);
        assertEq(box.MEMBERSHIP_DURATION(), 30 days);
    }

    function test_openBurnsWholeBoxesAndStartsMembership() public {
        vm.warp(1_000 days);

        vm.prank(alice);
        box.open(2);

        assertEq(box.balanceOf(alice), 8 ether);
        assertEq(box.totalSupply(), 98 ether);
        assertEq(box.openedBoxes(), 2);
        assertEq(box.membershipExpiry(alice), block.timestamp + 60 days);
        assertTrue(box.hasActiveMembership(alice));
        _assertSupplyInvariant();
    }

    function test_openExtendsActiveMembershipFromExistingExpiry() public {
        vm.warp(1_000 days);
        vm.startPrank(alice);
        box.open(1);
        uint256 firstExpiry = box.membershipExpiry(alice);

        vm.warp(block.timestamp + 7 days);
        box.open(2);
        vm.stopPrank();

        assertEq(box.membershipExpiry(alice), firstExpiry + 60 days);
        assertEq(box.openedBoxes(), 3);
        _assertSupplyInvariant();
    }

    function test_openExtendsExpiredMembershipFromCurrentTime() public {
        vm.warp(1_000 days);
        vm.prank(alice);
        box.open(1);

        vm.warp(block.timestamp + 31 days);
        vm.prank(alice);
        box.open(1);

        assertEq(box.membershipExpiry(alice), block.timestamp + 30 days);
        assertEq(box.openedBoxes(), 2);
        _assertSupplyInvariant();
    }

    function test_openZeroRevertsWithoutChangingState() public {
        vm.prank(alice);
        vm.expectRevert(OpenableERC20.InvalidBoxCount.selector);
        box.open(0);

        assertEq(box.balanceOf(alice), 10 ether);
        assertEq(box.openedBoxes(), 0);
        assertEq(box.membershipExpiry(alice), 0);
    }

    function test_membershipRejectsApplicationDataAtomically() public {
        vm.prank(alice);
        vm.expectRevert(DiscoveryBox.UnsupportedOpenData.selector);
        box.open(1, abi.encode("unexpected"));

        assertEq(box.balanceOf(alice), 10 ether);
        assertEq(box.openedCount(), 0);
        assertEq(box.membershipExpiry(alice), 0);
    }

    function test_openMoreThanBalanceRevertsWithoutChangingState() public {
        vm.prank(alice);
        vm.expectRevert();
        box.open(11);

        assertEq(box.balanceOf(alice), 10 ether);
        assertEq(box.openedBoxes(), 0);
        assertEq(box.membershipExpiry(alice), 0);
    }

    function test_fractionalBalanceCannotOpenAWholeBox() public {
        address fractionalHolder = makeAddr("fractionalHolder");
        assertTrue(box.transfer(fractionalHolder, 1 ether - 1));

        vm.prank(fractionalHolder);
        vm.expectRevert();
        box.open(1);

        assertEq(box.balanceOf(fractionalHolder), 1 ether - 1);
        assertEq(box.openedCount(), 0);
        assertEq(box.membershipExpiry(fractionalHolder), 0);
    }

    function test_fuzzOpenConservesSupply(uint8 rawBoxCount) public {
        uint256 boxCount = bound(uint256(rawBoxCount), 1, 10);

        vm.prank(alice);
        box.open(boxCount);

        assertEq(box.openedBoxes(), boxCount);
        assertEq(box.balanceOf(alice), (10 - boxCount) * 1 ether);
        _assertSupplyInvariant();
    }

    function test_allBoxesCanBeOpenedAcrossHolders() public {
        box.open(90);
        vm.prank(alice);
        box.open(10);

        assertEq(box.totalSupply(), 0);
        assertEq(box.openedBoxes(), 100);
        _assertSupplyInvariant();
    }

    function _assertSupplyInvariant() private view {
        assertEq(box.totalSupply() + box.openedBoxes() * box.BOX_UNIT(), box.INITIAL_SUPPLY());
    }
}
