// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import { OpenableERC20 } from "../openable/OpenableERC20.sol";

/// @title Discovery Collectible Box
/// @notice Burns unopened ERC-20 boxes and mints a transparent, deterministic ERC-1155 collectible series.
contract CollectibleBox is OpenableERC20, ERC1155 {
    uint256 public constant INITIAL_BOX_SUPPLY = 100;
    uint256 public constant MATURITY_TARGET = 40;
    uint256 public constant MAX_STYLE_COUNT = 100;

    uint256 public immutable styleCount;

    error InvalidStyleCount();
    error InvalidSerial();
    error UnsupportedOpenData();

    event CollectiblesRevealed(address indexed account, uint256 firstSerial, uint256 boxCount);

    constructor(address launchRecipient, uint256 styleCount_, string memory metadataUri)
        OpenableERC20("Discovery Collectible Box", "COLLECT", launchRecipient, INITIAL_BOX_SUPPLY, MATURITY_TARGET)
        ERC1155(metadataUri)
    {
        if (styleCount_ == 0 || styleCount_ > MAX_STYLE_COUNT) revert InvalidStyleCount();
        styleCount = styleCount_;
    }

    /// @notice Return the deterministic style assigned to a box serial number.
    function styleForSerial(uint256 serial) public view returns (uint256) {
        if (serial == 0 || serial > INITIAL_BOX_SUPPLY) revert InvalidSerial();
        return (serial - 1) % styleCount + 1;
    }

    function _afterOpen(address account, uint256 boxCount, uint256 firstSerial, bytes memory openData)
        internal
        override
    {
        if (openData.length != 0) revert UnsupportedOpenData();

        uint256[] memory styleIds = new uint256[](boxCount);
        uint256[] memory amounts = new uint256[](boxCount);
        for (uint256 i; i < boxCount; ++i) {
            styleIds[i] = styleForSerial(firstSerial + i);
            amounts[i] = 1;
        }

        _mintBatch(account, styleIds, amounts, bytes(""));
        emit CollectiblesRevealed(account, firstSerial, boxCount);
    }
}
