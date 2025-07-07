// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external

import { Helpers } from "@superform-v2-core/test/utils/Helpers.sol";

abstract contract PeripheryHelpers is Helpers {
    address constant VM_ADDR = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

    address public user1;
    address public user2;
    address public user3;
    address public constant MANAGER = address(0x9876564321);
    address public SV_MANAGER;
    address public STRATEGIST;
    address public EMERGENCY_ADMIN;
    address public VALIDATOR;

    function deployAccounts() public {
        // deploy accounts
        SV_MANAGER = _deployAccount(MANAGER_KEY, "SV_MANAGER");
        STRATEGIST = _deployAccount(STRATEGIST_KEY, "STRATEGIST");
        EMERGENCY_ADMIN = _deployAccount(EMERGENCY_ADMIN_KEY, "EMERGENCY_ADMIN");
        VALIDATOR = _deployAccount(VALIDATOR_KEY, "VALIDATOR");
    }
}
