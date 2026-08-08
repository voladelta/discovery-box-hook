// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { DiscoveryBox } from "./DiscoveryBox.sol";

/// @title Discovery Box Factory
/// @notice CREATE2 deployment boundary used by the atomic launch factory.
contract DiscoveryBoxFactory {
    error InvalidAddress();
    error UnauthorizedDeployer();

    function deploy(bytes32 salt, address launchRecipient) external returns (DiscoveryBox box) {
        if (launchRecipient == address(0)) revert InvalidAddress();
        if (msg.sender != launchRecipient) revert UnauthorizedDeployer();
        box = new DiscoveryBox{ salt: salt }(launchRecipient);
    }
}
