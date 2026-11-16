// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/access/AccessControl.sol";

/**
 * @title MedicineRegistry
 * @notice A public registry that lets anyone check whether a medicine batch is
 *         genuine, expired or recalled.
 *
 * Problem: counterfeit medicine looks real and patients cannot tell the difference.
 * Solution: approved manufacturers record each batch on-chain. Regulators can
 *           approve manufacturers and recall unsafe batches. Anyone can verify a
 *           batch for free, because verification is a read-only call.
 *
 * Roles
 *  - REGULATOR_ROLE    : approves/removes manufacturers and recalls batches.
 *  - MANUFACTURER_ROLE : registers new batches (only if approved by a regulator).
 *  - Everyone          : verifies batches (no role, no gas, no wallet needed).
 *
 * No ether or tokens are held or transferred by this contract.
 */
contract MedicineRegistry is AccessControl {
    // ---------------------------------------------------------------------
    // Roles
    // ---------------------------------------------------------------------

    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");

    // ---------------------------------------------------------------------
    // Types and storage
    // ---------------------------------------------------------------------

    /// @notice Result returned to anyone verifying a batch.
    enum Status {
        NotFound, // batch ID was never registered -> treat as suspicious
        Genuine, // registered, not expired, not recalled
        Expired, // registered but past its expiry date
        Recalled // withdrawn by a regulator (takes priority over Expired)
    }

    struct Batch {
        address manufacturer; // who registered the batch
        string drugName; // e.g. "Paracetamol 500mg"
        uint64 expiryDate; // unix timestamp
        uint64 registeredAt; // unix timestamp
        bool recalled; // set by a regulator
        string recallReason; // empty unless recalled
    }

    /// @dev batchId (printed on the package / QR code) => batch record
    mapping(string => Batch) private _batches;

    /// @notice Human-readable name of each approved manufacturer.
    mapping(address => string) public manufacturerName;

    /// @notice Number of batches ever registered (useful for dashboards/tests).
    uint256 public totalBatches;

    // ---------------------------------------------------------------------
    // Events (they form a public audit trail)
    // ---------------------------------------------------------------------

    event ManufacturerApproved(address indexed manufacturer, string name);
    event ManufacturerRemoved(address indexed manufacturer);
    event BatchRegistered(
        string indexed batchIdHash,
        string batchId,
        address indexed manufacturer,
        string drugName,
        uint64 expiryDate
    );
    event BatchRecalled(string indexed batchIdHash, string batchId, address indexed regulator, string reason);

    // ---------------------------------------------------------------------
    // Custom errors (cheaper than revert strings and easy to test)
    // ---------------------------------------------------------------------

    error ZeroAddress();
    error EmptyInput();
    error AlreadyApproved(address manufacturer);
    error NotApproved(address manufacturer);
    error BatchAlreadyExists(string batchId);
    error BatchDoesNotExist(string batchId);
    error AlreadyRecalled(string batchId);
    error ExpiryNotInFuture(uint64 expiryDate);

    // ---------------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------------

    /**
     * @param firstRegulator Address that receives the regulator role (and admin
     *        rights) at deployment. Additional regulators can be added later.
     */
    constructor(address firstRegulator) {
        if (firstRegulator == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, firstRegulator);
        _grantRole(REGULATOR_ROLE, firstRegulator);

        // Regulators (not just the deployer) administer manufacturers and regulators.
        _setRoleAdmin(MANUFACTURER_ROLE, REGULATOR_ROLE);
        _setRoleAdmin(REGULATOR_ROLE, REGULATOR_ROLE);
    }

    // ---------------------------------------------------------------------
    // Regulator actions
    // ---------------------------------------------------------------------

    /**
     * @notice Approve a manufacturer so it can register batches.
     * @param manufacturer Wallet address of the manufacturer.
     * @param name Public name shown to people who verify (e.g. "PharmaCo Ltd").
     */
    function approveManufacturer(address manufacturer, string calldata name) external onlyRole(REGULATOR_ROLE) {
        if (manufacturer == address(0)) revert ZeroAddress();
        if (bytes(name).length == 0) revert EmptyInput();
        if (hasRole(MANUFACTURER_ROLE, manufacturer)) revert AlreadyApproved(manufacturer);

        manufacturerName[manufacturer] = name;
        _grantRole(MANUFACTURER_ROLE, manufacturer);
        emit ManufacturerApproved(manufacturer, name);
    }

    /**
     * @notice Remove a manufacturer's right to register NEW batches.
     * @dev Batches they already registered stay on record; a regulator can recall
     *      any of them individually if needed.
     */
    function removeManufacturer(address manufacturer) external onlyRole(REGULATOR_ROLE) {
        if (!hasRole(MANUFACTURER_ROLE, manufacturer)) revert NotApproved(manufacturer);

        _revokeRole(MANUFACTURER_ROLE, manufacturer);
        emit ManufacturerRemoved(manufacturer);
    }

    /**
     * @notice Recall an unsafe or counterfeit batch. Verification will then
     *         report it as Recalled together with the reason.
     */
    function recallBatch(string calldata batchId, string calldata reason) external onlyRole(REGULATOR_ROLE) {
        if (bytes(reason).length == 0) revert EmptyInput();

        Batch storage batch = _batches[batchId];
        if (batch.registeredAt == 0) revert BatchDoesNotExist(batchId);
        if (batch.recalled) revert AlreadyRecalled(batchId);

        batch.recalled = true;
        batch.recallReason = reason;
        emit BatchRecalled(batchId, batchId, msg.sender, reason);
    }

    // ---------------------------------------------------------------------
    // Manufacturer actions
    // ---------------------------------------------------------------------

    /**
     * @notice Register a new medicine batch. Only approved manufacturers may call.
     * @param batchId Unique ID printed on the packaging (e.g. "PARA-2026-001").
     * @param drugName Name and strength of the medicine.
     * @param expiryDate Unix timestamp; must be in the future.
     */
    function registerBatch(
        string calldata batchId,
        string calldata drugName,
        uint64 expiryDate
    ) external onlyRole(MANUFACTURER_ROLE) {
        if (bytes(batchId).length == 0 || bytes(drugName).length == 0) revert EmptyInput();
        if (expiryDate <= block.timestamp) revert ExpiryNotInFuture(expiryDate);
        if (_batches[batchId].registeredAt != 0) revert BatchAlreadyExists(batchId);

        _batches[batchId] = Batch({
            manufacturer: msg.sender,
            drugName: drugName,
            expiryDate: expiryDate,
            registeredAt: uint64(block.timestamp),
            recalled: false,
            recallReason: ""
        });
        totalBatches += 1;

        emit BatchRegistered(batchId, batchId, msg.sender, drugName, expiryDate);
    }

    // ---------------------------------------------------------------------
    // Public verification (free, no wallet required)
    // ---------------------------------------------------------------------

    /**
     * @notice Check a batch. This is what a pharmacist or patient calls.
     * @return status NotFound, Genuine, Expired or Recalled.
     * @return batch The stored record (all zero values when NotFound).
     * @return manufacturerLabel Name of the manufacturer, as approved by a regulator.
     */
    function verifyBatch(
        string calldata batchId
    ) external view returns (Status status, Batch memory batch, string memory manufacturerLabel) {
        batch = _batches[batchId];

        if (batch.registeredAt == 0) {
            return (Status.NotFound, batch, "");
        }

        manufacturerLabel = manufacturerName[batch.manufacturer];

        if (batch.recalled) {
            status = Status.Recalled;
        } else if (block.timestamp >= batch.expiryDate) {
            status = Status.Expired;
        } else {
            status = Status.Genuine;
        }
    }
}
