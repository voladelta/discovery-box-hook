// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { CollectibleBox } from "../src/applications/CollectibleBox.sol";
import { TicketBox } from "../src/applications/TicketBox.sol";
import { IOpenableAsset } from "../src/openable/IOpenableAsset.sol";

contract OpenableApplicationsTest is Test {
    TicketBox internal ticketBox;
    CollectibleBox internal collectibleBox;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal gate = makeAddr("gate");

    function setUp() public {
        ticketBox = new TicketBox(address(this), gate, 3);
        collectibleBox = new CollectibleBox(address(this), 3, "ipfs://discovery/{id}.json");

        assertTrue(ticketBox.transfer(alice, 10 ether));
        assertTrue(collectibleBox.transfer(alice, 10 ether));
    }

    function test_genericInterfaceExposesOnlyMarketInputs() public view {
        IOpenableAsset ticketAsset = IOpenableAsset(address(ticketBox));
        IOpenableAsset collectibleAsset = IOpenableAsset(address(collectibleBox));

        assertEq(ticketAsset.openedCount(), 0);
        assertEq(ticketAsset.maturityTarget(), 40);
        assertEq(collectibleAsset.openedCount(), 0);
        assertEq(collectibleAsset.maturityTarget(), 40);
    }

    function test_ticketOpeningCreatesAndConsumesAdmissions() public {
        vm.prank(alice);
        ticketBox.open(2);

        assertEq(ticketBox.balanceOf(alice), 8 ether);
        assertEq(ticketBox.admissionBalance(alice), 6);
        assertEq(ticketBox.openedCount(), 2);

        vm.prank(gate);
        ticketBox.useAdmissions(alice, 4);
        assertEq(ticketBox.admissionBalance(alice), 2);
        _assertConservation(ticketBox.totalSupply(), ticketBox.openedCount(), ticketBox.initialSupply());
    }

    function test_ticketOpeningCanGiftTheOutcome() public {
        vm.prank(alice);
        ticketBox.open(1, abi.encode(bob));

        assertEq(ticketBox.balanceOf(alice), 9 ether);
        assertEq(ticketBox.admissionBalance(alice), 0);
        assertEq(ticketBox.admissionBalance(bob), 3);
    }

    function test_ticketRejectsMalformedOutcomeDataAtomically() public {
        vm.prank(alice);
        vm.expectRevert(TicketBox.InvalidOpenData.selector);
        ticketBox.open(1, hex"01");

        assertEq(ticketBox.balanceOf(alice), 10 ether);
        assertEq(ticketBox.openedCount(), 0);
        assertEq(ticketBox.admissionBalance(alice), 0);
    }

    function test_onlyGateCanConsumeAdmissions() public {
        vm.prank(alice);
        ticketBox.open(1);

        vm.prank(bob);
        vm.expectRevert(TicketBox.UnauthorizedGate.selector);
        ticketBox.useAdmissions(alice, 1);
        assertEq(ticketBox.admissionBalance(alice), 3);
    }

    function test_collectibleOpeningMintsDeterministicSeries() public {
        vm.prank(alice);
        collectibleBox.open(4);

        assertEq(collectibleBox.balanceOf(alice), 6 ether);
        assertEq(collectibleBox.openedCount(), 4);
        assertEq(collectibleBox.balanceOf(alice, 1), 2);
        assertEq(collectibleBox.balanceOf(alice, 2), 1);
        assertEq(collectibleBox.balanceOf(alice, 3), 1);
        assertEq(collectibleBox.styleForSerial(4), 1);
        _assertConservation(collectibleBox.totalSupply(), collectibleBox.openedCount(), collectibleBox.initialSupply());
    }

    function test_collectibleRejectsOutcomeDataAtomically() public {
        vm.prank(alice);
        vm.expectRevert(CollectibleBox.UnsupportedOpenData.selector);
        collectibleBox.open(1, abi.encode(uint256(2)));

        assertEq(collectibleBox.balanceOf(alice), 10 ether);
        assertEq(collectibleBox.openedCount(), 0);
        assertEq(collectibleBox.balanceOf(alice, 1), 0);
    }

    function test_collectibleReceiverCannotReenterOpening() public {
        ReentrantCollector receiver = new ReentrantCollector(collectibleBox);
        assertTrue(collectibleBox.transfer(address(receiver), 2 ether));

        receiver.openOne();

        assertTrue(receiver.reentryBlocked());
        assertEq(collectibleBox.balanceOf(address(receiver)), 1 ether);
        assertEq(collectibleBox.openedCount(), 1);
        assertEq(collectibleBox.balanceOf(address(receiver), 1), 1);
    }

    function _assertConservation(uint256 supply, uint256 opened, uint256 initialSupply) private pure {
        assertEq(supply + opened * 1 ether, initialSupply);
    }
}

contract ReentrantCollector is IERC1155Receiver {
    CollectibleBox public immutable box;
    bool public reentryBlocked;

    constructor(CollectibleBox box_) {
        box = box_;
    }

    function openOne() external {
        box.open(1);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        _attemptReentry();
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        returns (bytes4)
    {
        _attemptReentry();
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function _attemptReentry() private {
        try box.open(1) {
            revert("re-entry succeeded");
        } catch {
            reentryBlocked = true;
        }
    }
}
