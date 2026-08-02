// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import { IOpenableAsset } from "./IOpenableAsset.sol";

/// @title Openable ERC-20
/// @notice A fixed-supply asset that can be traded unopened or burned in whole units for an application outcome.
abstract contract OpenableERC20 is ERC20, IOpenableAsset, ReentrancyGuardTransient {
    uint256 public constant OPENING_UNIT = 1 ether;
    uint256 public constant MAX_OPEN_DATA_LENGTH = 1_024;

    uint256 public immutable initialSupply;
    uint256 public immutable override maturityTarget;
    uint256 public override openedCount;

    error InvalidLaunchRecipient();
    error InvalidSupply();
    error InvalidMaturityTarget();
    error InvalidBoxCount();
    error OpenDataTooLarge();

    event OpenableAssetCreated(address indexed asset, uint256 initialSupply, uint256 maturityTarget);

    constructor(
        string memory name_,
        string memory symbol_,
        address launchRecipient,
        uint256 wholeBoxSupply,
        uint256 maturityTarget_
    ) ERC20(name_, symbol_) {
        if (launchRecipient == address(0)) revert InvalidLaunchRecipient();
        if (wholeBoxSupply == 0 || wholeBoxSupply > type(uint256).max / OPENING_UNIT) revert InvalidSupply();
        if (maturityTarget_ == 0 || maturityTarget_ > wholeBoxSupply) revert InvalidMaturityTarget();

        initialSupply = wholeBoxSupply * OPENING_UNIT;
        maturityTarget = maturityTarget_;

        _mint(launchRecipient, initialSupply);
        emit OpenableAssetCreated(address(this), initialSupply, maturityTarget_);
    }

    function open(uint256 boxCount) external nonReentrant {
        _open(_msgSender(), boxCount, bytes(""));
    }

    function open(uint256 boxCount, bytes calldata openData) external nonReentrant {
        _open(_msgSender(), boxCount, openData);
    }

    /// @notice Backwards-compatible alias used by the membership prototype and its indexer.
    function openedBoxes() external view returns (uint256) {
        return openedCount;
    }

    function _open(address account, uint256 boxCount, bytes memory openData) private {
        if (boxCount == 0 || boxCount > initialSupply / OPENING_UNIT) revert InvalidBoxCount();
        if (openData.length > MAX_OPEN_DATA_LENGTH) revert OpenDataTooLarge();

        uint256 firstSerial = openedCount + 1;
        _burn(account, boxCount * OPENING_UNIT);
        openedCount += boxCount;

        _afterOpen(account, boxCount, firstSerial, openData);
        emit AssetOpened(account, boxCount, firstSerial, openedCount);
    }

    /// @dev Concrete assets own the opened outcome. A revert rolls back the burn and counter atomically.
    function _afterOpen(address account, uint256 boxCount, uint256 firstSerial, bytes memory openData) internal virtual;
}
