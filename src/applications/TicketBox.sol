// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { OpenableERC20 } from "../openable/OpenableERC20.sol";

/// @title Discovery Ticket Box
/// @notice Turns unopened ERC-20 boxes into non-transferable admissions consumed by one immutable gate.
contract TicketBox is OpenableERC20 {
    uint256 public constant INITIAL_BOX_SUPPLY = 100;
    uint256 public constant MATURITY_TARGET = 40;

    address public immutable gate;
    uint256 public immutable admissionsPerBox;
    mapping(address holder => uint256 admissions) public admissionBalance;

    error InvalidGate();
    error InvalidAdmissionsPerBox();
    error InvalidBeneficiary();
    error InvalidOpenData();
    error UnauthorizedGate();
    error InvalidAdmissionAmount();

    event AdmissionsCreated(address indexed opener, address indexed beneficiary, uint256 amount);
    event AdmissionsUsed(address indexed gate, address indexed holder, uint256 amount);

    constructor(address launchRecipient, address gate_, uint256 admissionsPerBox_)
        OpenableERC20("Discovery Ticket Box", "TICKET", launchRecipient, INITIAL_BOX_SUPPLY, MATURITY_TARGET)
    {
        if (gate_ == address(0)) revert InvalidGate();
        if (admissionsPerBox_ == 0 || admissionsPerBox_ > type(uint256).max / INITIAL_BOX_SUPPLY) {
            revert InvalidAdmissionsPerBox();
        }

        gate = gate_;
        admissionsPerBox = admissionsPerBox_;
    }

    /// @notice Consume admissions after the gate provides entry or another declared service.
    function useAdmissions(address holder, uint256 amount) external {
        if (msg.sender != gate) revert UnauthorizedGate();
        uint256 balance = admissionBalance[holder];
        if (amount == 0 || amount > balance) revert InvalidAdmissionAmount();

        admissionBalance[holder] = balance - amount;
        emit AdmissionsUsed(msg.sender, holder, amount);
    }

    function _afterOpen(address account, uint256 boxCount, uint256, bytes memory openData) internal override {
        address beneficiary = account;
        if (openData.length != 0) {
            if (openData.length != 32) revert InvalidOpenData();
            beneficiary = abi.decode(openData, (address));
            if (beneficiary == address(0)) revert InvalidBeneficiary();
        }

        uint256 amount = boxCount * admissionsPerBox;
        admissionBalance[beneficiary] += amount;
        emit AdmissionsCreated(account, beneficiary, amount);
    }
}
