// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../../../BaseTest.t.sol";
import { console } from "forge-std/console.sol";

contract GetAddressesFromBaseTest is BaseTest {
    function setUp() public override {
        // Call the BaseTest setUp which does all the deployment work
        super.setUp();
    }

    /**
     * @notice Get addresses for deterministic merkle tree generation
     * @dev This logs addresses for the merkle tree pre-generation system
     */
    function test_getAddresses() external view {
        // Add SuperVaults here
        console.log("globalSVStrategy:", globalSVStrategy);
        console.log("globalSVGearStrategy:", globalSVGearStrategy);
        console.log("globalRuggableVault:", globalRuggableVault);

        // Add vaults here
        console.log("VAULT_test1_DynamicAllocation_MockVault:", test1_DynamicAllocation_MockVault);
        console.log("VAULT_test3_UnderlyingVaults_StressTest:", test3_UnderlyingVaults_StressTest);
        console.log("VAULT_test6_yieldAccumulation_vault1:", test6_yieldAccumulation_vault1);
        console.log("VAULT_test6_yieldAccumulation_vault2:", test6_yieldAccumulation_vault2);
        console.log("VAULT_test6_yieldAccumulation_vault3:", test6_yieldAccumulation_vault3);
        console.log(
            "VAULT_test6_yieldAccumulation_WithRebalancing_vault1:", test6_yieldAccumulation_WithRebalancing_vault1
        );
        console.log(
            "VAULT_test6_yieldAccumulation_WithRebalancing_vault2:", test6_yieldAccumulation_WithRebalancing_vault2
        );
        console.log(
            "VAULT_test6_yieldAccumulation_WithRebalancing_vault3:", test6_yieldAccumulation_WithRebalancing_vault3
        );
        console.log("VAULT_test10_RuggableVault_Deposit:", test10_RuggableVault_Deposit);
        console.log("VAULT_test10_RuggableVault_Withdraw:", test10_RuggableVault_Withdraw);
        console.log(
            "VAULT_test10_RuggableVault_Withdraw_ConvertDistortion:", test10_RuggableVault_Withdraw_ConvertDistortion
        );
        console.log("VAULT_test11_Allocate_NewYieldSource:", test11_Allocate_NewYieldSource);
        console.log("VAULT_MOCK_ETH_RECEIVER:", contractAddresses[ETH]["MOCK_ETH_RECEIVER"]);

        // add hooks here
        console.log("ApproveAndDeposit4626VaultHook:", globalMerkleHooks[0]);
        console.log("Redeem4626VaultHook:", globalMerkleHooks[1]);
        console.log("ApproveAndGearboxStakeHook:", globalMerkleHooks[2]);
        console.log("GearboxUnstakeHook:", globalMerkleHooks[3]);
        console.log("MockNativeETHHook:", globalMerkleHooksPeriphery[0]);
    }
}
