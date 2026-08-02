// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { OpenableERC20 } from "./openable/OpenableERC20.sol";

/// @title Discovery Box
/// @notice A fixed-supply token that holders burn in whole units to activate a membership bundle.
contract DiscoveryBox is OpenableERC20 {
    uint256 public constant BOX_UNIT = 1 ether;
    uint256 public constant INITIAL_SUPPLY = 100 * BOX_UNIT;
    uint256 public constant MATURITY_TARGET = 40;
    uint256 public constant MEMBERSHIP_DURATION = 30 days;

    mapping(address account => uint256 expiry) public membershipExpiry;

    error UnsupportedOpenData();

    event DiscoveryBoxCreated(
        address indexed token, uint256 initialSupply, uint256 maturityTarget, uint256 membershipDuration
    );
    event BoxOpened(address indexed account, uint256 boxCount, uint256 newExpiry, uint256 totalOpenedBoxes);

    constructor(address launchRecipient) OpenableERC20("Discovery Box", "BOX", launchRecipient, 100, MATURITY_TARGET) {
        emit DiscoveryBoxCreated(address(this), INITIAL_SUPPLY, MATURITY_TARGET, MEMBERSHIP_DURATION);
    }

    function _afterOpen(address account, uint256 boxCount, uint256, bytes memory openData) internal override {
        if (openData.length != 0) revert UnsupportedOpenData();

        uint256 expiry = membershipExpiry[account];
        // A few seconds of timestamp variance is immaterial to a fixed 30-day membership duration.
        // forge-lint: disable-next-line(block-timestamp)
        uint256 base = expiry > block.timestamp ? expiry : block.timestamp;
        uint256 newExpiry = base + boxCount * MEMBERSHIP_DURATION;

        membershipExpiry[account] = newExpiry;
        emit BoxOpened(account, boxCount, newExpiry, openedCount);
    }

    function hasActiveMembership(address account) external view returns (bool) {
        // Membership expiry is intentionally defined against consensus block time.
        // forge-lint: disable-next-line(block-timestamp)
        return membershipExpiry[account] > block.timestamp;
    }
}
