// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {vm} from "@chimera/Hevm.sol";
import {Panic} from "@recon/Panic.sol";
import {MockERC20} from "@recon/MockERC20.sol";

import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
import {ISuperVaultStrategy} from "src/interfaces/SuperVault/ISuperVaultStrategy.sol";
import {YieldSourceType} from "test/recon/managers/YieldManager.sol";

abstract contract DoomsdayTargets is BaseTargetFunctions, Properties {
    /// Makes a handler have no side effects
    /// The fuzzer will call this anyway, and because it reverts it will be removed from shrinking
    /// Replace the "withGhosts" with "stateless" to make the code clean
    modifier stateless() {
        _;
        revert("stateless");
    }

    /// @dev Property: mint/redeem is symmetrical
    function doomsday_mintRedeemSymmetrical(
        uint256 sharesToMint
    ) public stateless {
        uint256 balanceBefore = MockERC20(_getAsset()).balanceOf(_getActor());

        // 1. Deposit
        superVault.mint(sharesToMint, _getActor());

        // 2. Request Redemption
        uint256 shares = superVault.balanceOf(_getActor());
        superVault.requestRedeem(shares, _getActor(), _getActor());

        // 3. Fulfill Redemption
        ISuperVaultStrategy.FulfillArgs
            memory fulfillArgs = _createFulfillRedeemArgs(shares);
        superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

        // 4. Claim Redemption
        superVault.redeem(shares, _getActor(), _getActor());

        uint256 balanceAfter = MockERC20(_getAsset()).balanceOf(_getActor());

        lte(
            balanceAfter,
            balanceBefore,
            "User gained assets in deposit/withdrawal flow"
        );
    }

    /// @dev Property: deposit/withdraw is symmetrical
    function doomsday_depositWithdrawSymmetrical(
        uint256 assetsToDeposit
    ) public stateless {
        uint256 balanceBefore = MockERC20(_getAsset()).balanceOf(_getActor());

        // 1. Deposit
        superVault.deposit(assetsToDeposit, _getActor());

        // 2. Request Withdrawal (through redemption in ERC7540)
        uint256 shares = superVault.balanceOf(_getActor());
        superVault.requestRedeem(shares, _getActor(), _getActor());

        // 3. Fulfill Withdrawal
        ISuperVaultStrategy.FulfillArgs
            memory fulfillArgs = _createFulfillRedeemArgs(shares);
        superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

        // 4. Claim Withdrawal
        uint256 withdrawableAssets = superVault.maxWithdraw(_getActor());
        superVault.withdraw(withdrawableAssets, _getActor(), _getActor());

        uint256 balanceAfter = MockERC20(_getAsset()).balanceOf(_getActor());

        lte(
            balanceAfter,
            balanceBefore,
            "User gained assets in deposit/withdrawal flow"
        );
    }

    /// @dev Property: maxRedeem is reset to 0 after full redemption
    function doomsday_maxRedeemResetsAfterFullRedemption(
        uint256 sharesToMint
    ) public stateless {
        // 1. Deposit to get shares
        superVault.mint(sharesToMint, _getActor());

        uint256 shares = superVault.maxRedeem(_getActor());

        // 2. Request full redemption
        superVault.requestRedeem(shares, _getActor(), _getActor());

        // 3. Fulfill the redemption request
        ISuperVaultStrategy.FulfillArgs
            memory fulfillArgs = _createFulfillRedeemArgs(shares);
        superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

        // 4. Check maxRedeem before claiming
        uint256 maxRedeemBeforeClaim = superVault.maxRedeem(_getActor());

        // 5. Claim the full redemption
        superVault.redeem(maxRedeemBeforeClaim, _getActor(), _getActor());

        // 6. Check maxRedeem is reset to 0 after full redemption
        uint256 maxRedeemAfterClaim = superVault.maxRedeem(_getActor());
        eq(
            maxRedeemAfterClaim,
            0,
            "maxRedeem should be reset to 0 after full redemption"
        );
    }

    /// @dev Property: maxWithdraw is reset to 0 after full withdrawal
    function doomsday_maxWithdrawResetsAfterFullWithdrawal(
        uint256 assetsToDeposit
    ) public stateless {
        // 1. Deposit to get shares
        superVault.deposit(assetsToDeposit, _getActor());

        uint256 shares = superVault.balanceOf(_getActor());

        // 2. Request redemption of all shares
        superVault.requestRedeem(shares, _getActor(), _getActor());

        // 3. Fulfill the redemption request
        ISuperVaultStrategy.FulfillArgs
            memory fulfillArgs = _createFulfillRedeemArgs(shares);
        superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

        // 4. Check maxWithdraw after fulfillment and use that value
        uint256 maxWithdrawable = superVault.maxWithdraw(_getActor());

        // 5. Withdraw the exact amount returned by maxWithdraw
        superVault.withdraw(maxWithdrawable, _getActor(), _getActor());

        // 6. Check maxWithdraw is reset to 0 after full withdrawal
        uint256 maxWithdrawAfter = superVault.maxWithdraw(_getActor());
        eq(
            maxWithdrawAfter,
            0,
            "maxWithdraw should be reset to 0 after full withdrawal"
        );
    }

    /// @dev Property: fulfillRedeemRequests doesn't redeem more than requested for multiple actors
    function doomsday_fulfillDoesntOverRedeemMultipleActors(
        uint256[3] memory sharesToMint,
        uint256[3] memory actorIndexes
    ) public stateless {
        address[] memory actors = _getActors();
        if (actors.length < 3) return; // Need at least 3 actors for this test

        // Arrays to track actors and their requests
        address[] memory testActors = new address[](3);
        uint256[] memory requestedShares = new uint256[](3);
        uint256[] memory sharesBefore = new uint256[](3);

        // 1. Setup: Each actor deposits and requests redemption
        for (uint256 i = 0; i < 3; i++) {
            // Get unique actor
            testActors[i] = actors[actorIndexes[i] % actors.length];

            // Switch to this actor
            vm.startPrank(testActors[i]);

            // Mint shares for this actor
            if (sharesToMint[i] > 0) {
                superVault.mint(sharesToMint[i], testActors[i]);
            }

            // Get actual share balance
            sharesBefore[i] = superVault.balanceOf(testActors[i]);
            requestedShares[i] = sharesBefore[i];

            // Request redemption of all shares
            if (requestedShares[i] > 0) {
                superVault.requestRedeem(
                    requestedShares[i],
                    testActors[i],
                    testActors[i]
                );
            }

            vm.stopPrank();
        }

        // 2. Create multi-actor FulfillArgs
        ISuperVaultStrategy.FulfillArgs
            memory fulfillArgs = _createMultiActorFulfillArgs(
                testActors,
                requestedShares
            );

        // Calculate total expected from FulfillArgs
        uint256 totalExpectedFromArgs = 0;
        for (
            uint256 i = 0;
            i < fulfillArgs.expectedAssetsOrSharesOut.length;
            i++
        ) {
            totalExpectedFromArgs += fulfillArgs.expectedAssetsOrSharesOut[i];
        }

        // Get SuperVaultStrategy balance before fulfillment
        uint256 strategyBalanceBefore = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );

        // 3. Fulfill all redemption requests at once
        superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

        // Get SuperVaultStrategy balance after fulfillment
        uint256 strategyBalanceAfter = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );

        // 4. Calculate total fulfilled as the change in strategy balance
        // If balance increased, that's the amount fulfilled (assets moved into strategy)
        uint256 totalFulfilled = 0;
        if (strategyBalanceAfter > strategyBalanceBefore) {
            totalFulfilled = strategyBalanceAfter - strategyBalanceBefore;
        }

        // 5. Check individual actors' maxRedeem values
        for (uint256 i = 0; i < 3; i++) {
            if (requestedShares[i] > 0) {
                uint256 maxRedeemable = superVault.maxRedeem(testActors[i]);

                lte(
                    maxRedeemable,
                    requestedShares[i],
                    "Actor's maxRedeem should not exceed requested shares"
                );

                // Also verify pending request was properly reduced
                uint256 pendingRequest = superVaultStrategy
                    .pendingRedeemRequest(testActors[i]);
                eq(
                    pendingRequest,
                    0,
                    "Pending redeem request should be cleared after fulfillment"
                );
            }
        }

        // 6. Critical check: Total assets transferred to strategy must not exceed sum of expectedAssetsOrSharesOut
        lte(
            totalFulfilled,
            totalExpectedFromArgs,
            "Total assets transferred to strategy should not exceed sum of expectedAssetsOrSharesOut"
        );
    }

    // Helpers

    /// @dev Helper function to create FulfillArgs for multiple actors
    function _createMultiActorFulfillArgs(
        address[] memory controllers,
        uint256[] memory amounts
    ) internal view returns (ISuperVaultStrategy.FulfillArgs memory) {
        uint256 numActors = controllers.length;

        address[] memory hooks = new address[](numActors);
        bytes[] memory hookCalldata = new bytes[](numActors);
        uint256[] memory expectedAssetsOrSharesOut = new uint256[](numActors);
        bytes32[][] memory globalProofs = new bytes32[][](numActors);
        bytes32[][] memory strategyProofs = new bytes32[][](numActors);

        for (uint256 i = 0; i < numActors; i++) {
            hooks[i] = _getRedeemHookForType(
                _getYieldSourceTypeFromAddress(_getYieldSource())
            );

            if (
                _getYieldSourceTypeFromAddress(_getYieldSource()) ==
                YieldSourceType.ERC4626
            ) {
                hookCalldata[i] = abi.encodePacked(
                    bytes32(0),
                    _getYieldSource(),
                    address(superVaultStrategy),
                    amounts[i],
                    false
                );
            } else {
                hookCalldata[i] = abi.encodePacked(
                    bytes32(0),
                    _getYieldSource(),
                    amounts[i],
                    false
                );
            }

            expectedAssetsOrSharesOut[i] = amounts[i];
            globalProofs[i] = new bytes32[](0);
            strategyProofs[i] = new bytes32[](0);
        }

        return
            ISuperVaultStrategy.FulfillArgs({
                controllers: controllers,
                hooks: hooks,
                hookCalldata: hookCalldata,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: globalProofs,
                strategyProofs: strategyProofs
            });
    }

    /// @dev Helper function to create FulfillArgs for redeem requests
    function _createFulfillRedeemArgs(
        uint256 amount
    ) internal view returns (ISuperVaultStrategy.FulfillArgs memory) {
        address[] memory controllers = new address[](1);
        controllers[0] = _getActor();

        address[] memory hooks = new address[](1);
        hooks[0] = _getRedeemHookForType(
            _getYieldSourceTypeFromAddress(_getYieldSource())
        );

        bytes[] memory hookCalldata = new bytes[](1);
        if (
            _getYieldSourceTypeFromAddress(_getYieldSource()) ==
            YieldSourceType.ERC4626
        ) {
            hookCalldata[0] = abi.encodePacked(
                bytes32(0),
                _getYieldSource(),
                address(superVaultStrategy),
                amount,
                false
            );
        } else {
            hookCalldata[0] = abi.encodePacked(
                bytes32(0),
                _getYieldSource(),
                amount,
                false
            );
        }

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        expectedAssetsOrSharesOut[0] = amount;

        bytes32[][] memory globalProofs = new bytes32[][](1);
        globalProofs[0] = new bytes32[](0);

        bytes32[][] memory strategyProofs = new bytes32[][](1);
        strategyProofs[0] = new bytes32[](0);

        return
            ISuperVaultStrategy.FulfillArgs({
                controllers: controllers,
                hooks: hooks,
                hookCalldata: hookCalldata,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: globalProofs,
                strategyProofs: strategyProofs
            });
    }
}
