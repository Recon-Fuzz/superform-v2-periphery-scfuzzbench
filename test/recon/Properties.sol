// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";

import {OpType} from "test/recon/BeforeAfter.sol";
import {BeforeAfter} from "./BeforeAfter.sol";

abstract contract Properties is BeforeAfter, Asserts {
    /// @dev Property: oracle PPS doesn't change on deposit/mint/redeem/withdraw
    function property_oraclePPSDoesntChangeOnAddOrRemove() public {
        if (_currentOp == OpType.ADD || _currentOp == OpType.REMOVE) {
            eq(
                _before.oraclePPS,
                _after.oraclePPS,
                "deposit/withdrawal changes oracle PPS"
            );
        }
    }

    /// @dev Property: naive PPS doesn't change on deposit/mint/redeem/withdraw
    function property_naivePPSDoesntChangeOnAddOrRemove() public {
        if (_currentOp == OpType.ADD || _currentOp == OpType.REMOVE) {
            eq(
                _before.naivePPS,
                _after.naivePPS,
                "deposit/withdrawal changes naive PPS"
            );
        }
    }
}
