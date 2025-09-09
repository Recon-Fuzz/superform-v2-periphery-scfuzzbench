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

    /// @dev Property: deposit/redeem is symmetrical
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
