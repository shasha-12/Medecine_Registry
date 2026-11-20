// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/access/AccessControl.sol";

/**
 * @title MedicineRegistry
 * @notice Public record of medicine batches. Anyone can check whether a batch
 *         is genuine, expired or recalled.
 *
 * Fake medicine looks the same as the real thing, so the batches are written
 * on the blockchain where nobody can quietly change them. Only manufacturers
 * approved by a regulator can add batches, and a regulator can recall a batch
 * that turns out to be unsafe. Checking a batch is a read-only call, so it is free.
 *
 * Roles:
 *  - regulator: approves manufacturers and recalls batches
 *  - manufacturer: registers batches
 *  - anyone: checks batches
 *
 * The contract never holds or sends any ether.
 */
contract MedicineRegistry is AccessControl {
    // the two roles
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");

    // data
    /// @notice What a check can return.
    enum Status {
        NotFound, // the batch ID was never registered
        Genuine, // registered, not expired and not recalled
        Expired, // registered but the expiry date has passed
        Recalled // a regulator withdrew it (this wins over Expired)
    }

    struct Batch {
        address manufacturer; // who registered it
        string drugName; // for example "Paracetamol 500mg"
        uint64 expiryDate; // unix time
        uint64 registeredAt; // unix time
        bool recalled; // only a regulator sets this
        string recallReason; // empty if not recalled
    }

    /// @dev batch ID printed on the pack => its record
    mapping(string => Batch) private _batches;

    /// @notice Name of each approved manufacturer.
    mapping(address => string) public manufacturerName;

    /// @notice How many batches have been registered so far.
    uint256 public totalBatches;

    // events, so every change can be seen publicly
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

    // errors
    error ZeroAddress();
    error EmptyInput();
    error AlreadyApproved(address manufacturer);
    error NotApproved(address manufacturer);
    error BatchAlreadyExists(string batchId);
    error BatchDoesNotExist(string batchId);
    error AlreadyRecalled(string batchId);
    error ExpiryNotInFuture(uint64 expiryDate);

    /**
     * @param firstRegulator the address that becomes the first regulator.
     *        More regulators can be added later.
     */
    constructor(address firstRegulator) {
        if (firstRegulator == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, firstRegulator);
        _grantRole(REGULATOR_ROLE, firstRegulator);

        // regulators manage the manufacturer and regulator roles
        _setRoleAdmin(MANUFACTURER_ROLE, REGULATOR_ROLE);
        _setRoleAdmin(REGULATOR_ROLE, REGULATOR_ROLE);
    }

    // regulator functions

    /**
     * @notice Approve a manufacturer so it can register batches.
     * @param manufacturer wallet address of the manufacturer
     * @param name name people will see when they check a batch, e.g. "PharmaCo Ltd"
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
     * @notice Stop a manufacturer from registering new batches.
     * @dev Their old batches stay on record. A regulator can still recall them one by one.
     */
    function removeManufacturer(address manufacturer) external onlyRole(REGULATOR_ROLE) {
        if (!hasRole(MANUFACTURER_ROLE, manufacturer)) revert NotApproved(manufacturer);

        _revokeRole(MANUFACTURER_ROLE, manufacturer);
        emit ManufacturerRemoved(manufacturer);
    }

    /**
     * @notice Recall an unsafe batch. After this, checking it shows Recalled
     *         and the reason.
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

    // manufacturer function

    /**
     * @notice Register a new batch. Only approved manufacturers can do this.
     * @param batchId ID printed on the pack, e.g. "PARA-2026-001". It must be new.
     * @param drugName name and strength of the medicine
     * @param expiryDate unix time, must be in the future
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

    // anyone can call this one for free

    /**
     * @notice Check a batch. A pharmacist or patient would use this.
     * @return status NotFound, Genuine, Expired or Recalled
     * @return batch the saved record (empty if NotFound)
     * @return manufacturerLabel the manufacturer's name
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
