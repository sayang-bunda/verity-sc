// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MockKeystoneForwarder
 * @notice Simulates Chainlink DON's Keystone Forwarder for hackathon/local testing.
 *
 * Production: CRE DON → Keystone Forwarder → Verity.onReport (msg.sender = Keystone)
 * Hackathon:  User/CRE → MockKeystoneForwarder.forward → Verity.onReport (msg.sender = this)
 *
 * Verity must be deployed with CRE_ADDRESS = address(this) so onlyCre allows this contract.
 */
contract MockKeystoneForwarder {
    address public verity;

    event ReportForwarded(bytes32 indexed workflowId, uint8 action);

    constructor(address _verity) {
        verity = _verity; // Can be 0x0; set via setVerity after Verity deploy
    }

    /// @notice Set Verity address (call after Verity deployed if constructor used 0x0)
    function setVerity(address _verity) external {
        if (_verity == address(0)) revert("Invalid Verity");
        verity = _verity;
    }

    /**
     * @notice Forward report to Verity. Simulates Keystone Forwarder.
     * @dev User/CRE workflow calls this with (metadata, report). Verity receives msg.sender = this contract.
     */
    function forward(bytes calldata metadata, bytes calldata report) external {
        if (verity == address(0)) revert("Verity not set");
        (bool ok, ) = verity.call(
            abi.encodeWithSignature("onReport(bytes,bytes)", metadata, report)
        );
        if (!ok) revert("Forward failed");
        uint8 action = abi.decode(report, (uint8));
        bytes32 workflowId;
        if (metadata.length >= 32) {
            workflowId = bytes32(metadata[:32]);
        }
        emit ReportForwarded(workflowId, action);
    }
}
