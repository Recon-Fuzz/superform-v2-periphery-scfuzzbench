// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {CryticAsserts} from "@chimera/CryticAsserts.sol";

import {TargetFunctions} from "./TargetFunctions.sol";

// echidna test/recon/CryticTester.sol --contract CryticTester --config echidna.yaml --format text --test-limit 1000000 --disable-slither
// medusa fuzz
contract CryticTester is TargetFunctions, CryticAsserts {
    constructor() payable {
        setup();
    }

    /// @dev Keep assertion-canary name aligned with Foundry wrapper for parser consistency.
    function invariant_assertion_failure_CANARY() public returns (bool) {
        assert_canary(0);
        return false;
    }
}
