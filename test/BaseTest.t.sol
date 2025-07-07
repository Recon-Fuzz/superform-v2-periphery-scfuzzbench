// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { PeripheryHelpers } from "./utils/PeripheryHelpers.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";

// Import core BaseTest
import { BaseTest as CoreBaseTest } from "@superform-v2-core/test/BaseTest.t.sol";

// Periphery-specific imports
import { SuperGovernor } from "../src/periphery/SuperGovernor.sol";
import { SuperBank } from "../src/periphery/SuperBank.sol";
import { SuperOracle } from "../src/periphery/oracles/SuperOracle.sol";
import { SuperVaultAggregator } from "../src/periphery/SuperVault/SuperVaultAggregator.sol";
import { SuperVault } from "../src/periphery/SuperVault/SuperVault.sol";
import { SuperVaultStrategy } from "../src/periphery/SuperVault/SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../src/periphery/SuperVault/SuperVaultEscrow.sol";
import { ECDSAPPSOracle } from "../src/periphery/oracles/ECDSAPPSOracle.sol";

import "forge-std/console2.sol";

struct PeripheryAddresses {
    SuperGovernor superGovernor;
    SuperBank superBank;
    SuperOracle oracleRegistry;
    SuperVaultAggregator superVaultAggregator;
    ECDSAPPSOracle ecdsappsOracle;
}

contract BaseTest is PeripheryHelpers, CoreBaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;
    using Clones for address;

    /*//////////////////////////////////////////////////////////////
                           PERIPHERY STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Periphery-specific mappings
    mapping(uint64 chainId => mapping(string contractName => address contractAddress)) public peripheryContractAddresses;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Call core setup first
        super.setUp();

        // Deploy periphery contracts
        PeripheryAddresses[] memory PA = new PeripheryAddresses[](chainIds.length);
        PA = _deployPeripheryContracts(PA);

        // Configure periphery
        _configurePeripheryGovernor(PA);

        // Register periphery hooks
        _registerPeripheryHooks(PA);
    }

    /*//////////////////////////////////////////////////////////////
                          PERIPHERY DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function _deployPeripheryContracts(PeripheryAddresses[] memory PA) internal returns (PeripheryAddresses[] memory) {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            PA[i].superGovernor = new SuperGovernor{ salt: SALT }(
                address(this), address(this), address(this), TREASURY, POLYMER_PROVER[chainIds[i]]
            );
            vm.label(address(PA[i].superGovernor), SUPER_GOVERNOR_KEY);
            peripheryContractAddresses[chainIds[i]][SUPER_GOVERNOR_KEY] = address(PA[i].superGovernor);

            PA[i].superBank = new SuperBank{ salt: SALT }(address(PA[i].superGovernor));
            vm.label(address(PA[i].superBank), SUPER_BANK_KEY);
            peripheryContractAddresses[chainIds[i]][SUPER_BANK_KEY] = address(PA[i].superBank);

            // Update TREASURY to point to SuperBank
            TREASURY = address(PA[i].superBank);

            PA[i].oracleRegistry = new SuperOracle{ salt: SALT }(
                address(this), new address[](0), new address[](0), new bytes32[](0), new address[](0)
            );
            vm.label(address(PA[i].oracleRegistry), SUPER_ORACLE_KEY);
            peripheryContractAddresses[chainIds[i]][SUPER_ORACLE_KEY] = address(PA[i].oracleRegistry);

            PA[i].ecdsappsOracle = new ECDSAPPSOracle(address(PA[i].superGovernor));
            vm.label(address(PA[i].ecdsappsOracle), ECDSAPPS_ORACLE_KEY);
            peripheryContractAddresses[chainIds[i]][ECDSAPPS_ORACLE_KEY] = address(PA[i].ecdsappsOracle);

            // Deploy implementation contracts first
            address vaultImpl = address(new SuperVault());
            address strategyImpl = address(new SuperVaultStrategy());
            address escrowImpl = address(new SuperVaultEscrow());

            PA[i].superVaultAggregator =
                new SuperVaultAggregator(address(PA[i].superGovernor), vaultImpl, strategyImpl, escrowImpl);
            vm.label(address(PA[i].superVaultAggregator), SUPER_VAULT_AGGREGATOR_KEY);
            peripheryContractAddresses[chainIds[i]][SUPER_VAULT_AGGREGATOR_KEY] = address(PA[i].superVaultAggregator);

            // Set up governor configurations
            PA[i].superGovernor.setActivePPSOracle(address(PA[i].ecdsappsOracle));
            PA[i].superGovernor.addValidator(VALIDATOR);
        }
        return PA;
    }

    function _configurePeripheryGovernor(PeripheryAddresses[] memory PA) internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            SuperGovernor superGovernor = PA[i].superGovernor;

            superGovernor.setAddress(superGovernor.SUPER_VAULT_AGGREGATOR(), address(PA[i].superVaultAggregator));

            superGovernor.setAddress(superGovernor.TREASURY(), TREASURY);
        }
    }

    /**
     * @notice Registers periphery-specific hooks with the governor
     * @param PA Array of PeripheryAddresses structs containing periphery contract addresses
     */
    function _registerPeripheryHooks(PeripheryAddresses[] memory PA) internal {
        if (DEBUG) console2.log("---------------- REGISTERING PERIPHERY HOOKS ----------------");
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            SuperGovernor superGovernor = PA[i].superGovernor;

            console2.log("Registering periphery hooks for chain", chainIds[i]);

            // Register fulfillRequests hooks
            superGovernor.registerHook(_getContract(chainIds[i], DEPOSIT_4626_VAULT_HOOK_KEY), true);
            superGovernor.registerHook(_getContract(chainIds[i], REDEEM_4626_VAULT_HOOK_KEY), true);
            superGovernor.registerHook(_getContract(chainIds[i], DEPOSIT_5115_VAULT_HOOK_KEY), true);
            superGovernor.registerHook(_getContract(chainIds[i], REDEEM_5115_VAULT_HOOK_KEY), true);
            superGovernor.registerHook(_getContract(chainIds[i], REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], REQUEST_REDEEM_7540_VAULT_HOOK_KEY), false);

            // Register remaining hooks
            superGovernor.registerHook(_getContract(chainIds[i], APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY), true);
            superGovernor.registerHook(_getContract(chainIds[i], APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY), true);
            superGovernor.registerHook(_getContract(chainIds[i], APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY), true);
            superGovernor.registerHook(_getContract(chainIds[i], APPROVE_ERC20_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], TRANSFER_ERC20_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], DEPOSIT_7540_VAULT_HOOK_KEY), true);
            superGovernor.registerHook(_getContract(chainIds[i], WITHDRAW_7540_VAULT_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], APPROVE_AND_REQUEST_REDEEM_7540_VAULT_HOOK_KEY), true);
            superGovernor.registerHook(_getContract(chainIds[i], SWAP_1INCH_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], SWAP_ODOSV2_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], APPROVE_AND_SWAP_ODOSV2_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], FLUID_CLAIM_REWARD_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], FLUID_STAKE_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], APPROVE_AND_FLUID_STAKE_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], FLUID_UNSTAKE_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], GEARBOX_CLAIM_REWARD_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], GEARBOX_STAKE_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], GEARBOX_APPROVE_AND_STAKE_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], GEARBOX_UNSTAKE_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], YEARN_CLAIM_ONE_REWARD_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], CANCEL_REDEEM_REQUEST_7540_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], CANCEL_REDEEM_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], MINT_SUPERPOSITIONS_HOOK_KEY), false);

            // EXPERIMENTAL HOOKS FROM HERE ONWARDS
            superGovernor.registerHook(_getContract(chainIds[i], ETHENA_COOLDOWN_SHARES_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], ETHENA_UNSTAKE_HOOK_KEY), true);
            superGovernor.registerHook(_getContract(chainIds[i], MORPHO_BORROW_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], MORPHO_REPAY_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], PENDLE_ROUTER_REDEEM_HOOK_KEY), false);
            superGovernor.registerHook(_getContract(chainIds[i], OFFRAMP_TOKENS_HOOK_KEY), false);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          PERIPHERY GETTERS
    //////////////////////////////////////////////////////////////*/

    function _getPeripheryContract(uint64 chainId, string memory contractName) internal view returns (address) {
        return peripheryContractAddresses[chainId][contractName];
    }

    /*//////////////////////////////////////////////////////////////
                          OVERRIDE CORE SETUP
    //////////////////////////////////////////////////////////////*/

    function _setupSuperLedger() internal override {
        console2.log("------ periphery base test MANAGER", MANAGER);
        for (uint256 i; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            vm.startPrank(MANAGER);
            SuperGovernor superGovernor = SuperGovernor(_getPeripheryContract(chainIds[i], SUPER_GOVERNOR_KEY));
            ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
                new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](4);
            configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracle: _getContract(chainIds[i], ERC4626_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: superGovernor.getAddress(keccak256("TREASURY")),
                ledger: _getContract(chainIds[i], SUPER_LEDGER_KEY)
            });
            configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracle: _getContract(chainIds[i], ERC7540_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: superGovernor.getAddress(keccak256("TREASURY")),
                ledger: _getContract(chainIds[i], SUPER_LEDGER_KEY)
            });
            configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracle: _getContract(chainIds[i], ERC5115_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: superGovernor.getAddress(keccak256("TREASURY")),
                ledger: _getContract(chainIds[i], ERC1155_LEDGER_KEY)
            });
            configs[3] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracle: _getContract(chainIds[i], STAKING_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: superGovernor.getAddress(keccak256("TREASURY")),
                ledger: _getContract(chainIds[i], SUPER_LEDGER_KEY)
            });
            bytes32[] memory salts = new bytes32[](4);
            salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
            salts[1] = bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY));
            salts[2] = bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY));
            salts[3] = bytes32(bytes(STAKING_YIELD_SOURCE_ORACLE_KEY));
            ISuperLedgerConfiguration(_getContract(chainIds[i], SUPER_LEDGER_CONFIGURATION_KEY)).setYieldSourceOracles(
                salts, configs
            );
            vm.stopPrank();
        }
    }
}
