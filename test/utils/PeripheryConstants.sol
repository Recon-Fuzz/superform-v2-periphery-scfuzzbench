// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Constants } from "@superform-v2-core/test/utils/Constants.sol";

abstract contract PeripheryConstants is Constants {
    string public constant SUPER_ORACLE_KEY = "SuperOracle";
    string public constant SUPER_GOVERNOR_KEY = "SuperGovernor";
    string public constant SUPER_BANK_KEY = "SuperBank";
    string public constant SUPER_VAULT_AGGREGATOR_KEY = "SUPER_VAULT_AGGREGATOR";
    string public constant ECDSAPPS_ORACLE_KEY = "ECDSAPPS_ORACLE";

    address public constant CHAIN_1_POLYMER_PROVER = 0x441f16587d8a8cACE647352B24E1Aefa55ACEA76;
    address public constant CHAIN_10_POLYMER_PROVER = address(0); // not available
    address public constant CHAIN_8453_POLYMER_PROVER = address(0); // not available
}
