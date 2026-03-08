// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title KeystoneOnReportAdapter
 * @notice Jembatan antara Real Chainlink Keystone Forwarder dan Verity.
 *
 * Staging flow:
 *   CRE SDK → Real Keystone Forwarder → KeystoneOnReportAdapter.onReport()
 *          → Verity.onReport() (msg.sender = adapter = CRE_ROLE)
 *
 * Syarat deploy: grant CRE_ROLE ke address(this) di Verity.
 */
contract KeystoneOnReportAdapter {
    address public immutable verity;

    constructor(address _verity) {
        require(_verity != address(0), "Invalid verity");
        verity = _verity;
    }

    /**
     * @notice Dipanggil oleh Real Chainlink Keystone Forwarder.
     * @dev Forward langsung ke Verity.onReport(). msg.sender = address(this) = CRE_ROLE.
     */
    function onReport(bytes calldata metadata, bytes calldata report) external {
        (bool ok, ) = verity.call(
            abi.encodeWithSignature("onReport(bytes,bytes)", metadata, report)
        );
        require(ok, "Verity onReport failed");
    }
}
