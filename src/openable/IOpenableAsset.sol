// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Openable asset interface
/// @notice The stable boundary between an openable asset and its market hook.
interface IOpenableAsset {
    event AssetOpened(address indexed account, uint256 boxCount, uint256 firstSerial, uint256 totalOpenedCount);

    function openedCount() external view returns (uint256);

    function maturityTarget() external view returns (uint256);

    function open(uint256 boxCount) external;

    function open(uint256 boxCount, bytes calldata openData) external;
}
