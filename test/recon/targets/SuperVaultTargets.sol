// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Recon deps
import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {vm} from "@chimera/Hevm.sol";
import {Panic} from "@recon/Panic.sol";
import {MockERC20} from "@recon/MockERC20.sol";

import "src/SuperVault/SuperVault.sol";

import {BeforeAfter, OpType} from "test/recon/BeforeAfter.sol";
import {Properties} from "../Properties.sol";

/// @dev All receivers are inherently clamped to actors to make checking properties easier
abstract contract SuperVaultTargets is BaseTargetFunctions, Properties {
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///
    function superVault_requestRedeem_clamped(uint256 shares) public {
        shares %= superVault.balanceOf(_getActor()) + 1;

        superVault_requestRedeem(shares);
    }

    function superVault_redeem_clamped(uint256 shares) public {
        uint256 claimableAssets = superVault.maxWithdraw(_getActor());
        uint256 claimableShares = superVault.convertToShares(claimableAssets);

        shares %= claimableShares + 1;

        superVault_redeem(shares);
    }

    function superVault_withdraw_clamped(uint256 assets) public {
        uint256 claimableAssets = superVault.maxWithdraw(_getActor());
        assets %= claimableAssets + 1;

        superVault_withdraw(assets);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function superVault_approve(address spender, uint256 value) public asActor {
        superVault.approve(spender, value);
    }

    function superVault_burnShares(uint256 amount) public asActor {
        superVault.burnShares(amount);
    }

    struct CancelRedeemContext {
        uint256 pendingRedeemRequestsAsAssets;
        uint256 pendingRedeemRequestsAfter;
        uint256 averageRequestPPS;
        uint256 balanceBefore;
        uint256 balanceAfter;
    }

    struct TransferContext {
        bool success;
        bool expectedError;
        uint256 senderAccumulatorSharesDelta;
        uint256 recipientAccumulatorSharesDelta;
        uint256 senderAccumulatorCostBasisDelta;
        uint256 recipientAccumulatorCostBasisDelta;
    }

    function _executeCancelRedeem()
        internal
        returns (CancelRedeemContext memory context)
    {
        uint256 pendingRedeemRequestsBefore = superVault.pendingRedeemRequest(
            0,
            _getActor()
        );
        context.pendingRedeemRequestsAsAssets = superVault.convertToAssets(
            pendingRedeemRequestsBefore
        );
        context.balanceBefore = MockERC20(superVault.asset()).balanceOf(
            _getActor()
        );

        vm.prank(_getActor());
        superVault.cancelRedeem(_getActor());

        context.pendingRedeemRequestsAfter = superVault.pendingRedeemRequest(
            0,
            _getActor()
        );
        context.averageRequestPPS = superVaultStrategy
            .getSuperVaultState(_getActor())
            .averageRequestPPS;
        context.balanceAfter = MockERC20(superVault.asset()).balanceOf(
            _getActor()
        );
    }

    /// @dev Action: cancel a pending redemption request for the current actor.
    function superVault_cancelRedeem()
        public
        updateGhostsWithOpType(OpType.CANCEL)
    {
        _executeCancelRedeem();
    }

    /// @dev Property: pendingRedeemRequest should be 0 after a user calls cancelRedeem
    function superVault_cancelRedeem_ASSERTION_CANCEL_REDEEM_PENDING_REQUEST_ZERO()
        public
        updateGhostsWithOpType(OpType.CANCEL)
    {
        CancelRedeemContext memory context = _executeCancelRedeem();

        eq(
            context.pendingRedeemRequestsAfter,
            0,
            ASSERTION_CANCEL_REDEEM_PENDING_REQUEST_ZERO
        );
    }

    /// @dev Property: averageRequestPPS should be 0 after a user calls cancelRedeem
    function superVault_cancelRedeem_ASSERTION_CANCEL_REDEEM_AVG_REQUEST_PPS_ZERO()
        public
        updateGhostsWithOpType(OpType.CANCEL)
    {
        CancelRedeemContext memory context = _executeCancelRedeem();

        eq(
            context.averageRequestPPS,
            0,
            ASSERTION_CANCEL_REDEEM_AVG_REQUEST_PPS_ZERO
        );
    }

    /// @dev Property: user should not receive more than convertToAssets(pendingRedeemRequest) after cancelRedeem
    function superVault_cancelRedeem_ASSERTION_CANCEL_REDEEM_NO_OVERPAY()
        public
        updateGhostsWithOpType(OpType.CANCEL)
    {
        CancelRedeemContext memory context = _executeCancelRedeem();
        uint256 refundedAssets = context.balanceAfter > context.balanceBefore
            ? context.balanceAfter - context.balanceBefore
            : 0;

        lte(
            refundedAssets,
            context.pendingRedeemRequestsAsAssets,
            ASSERTION_CANCEL_REDEEM_NO_OVERPAY
        );
    }

    /// @dev Action: deposit assets for the current actor.
    function superVault_deposit(
        uint256 assets
    ) public updateGhostsWithOpType(OpType.ADD) {
        vm.prank(_getActor());
        superVault.deposit(assets, _getActor());
    }

    /// @dev Property: previewDeposit returns the correct amounts compared to executing a deposit
    function superVault_deposit_ASSERTION_PREVIEW_DEPOSIT_MATCHES_EXECUTION(
        uint256 assets
    ) public updateGhostsWithOpType(OpType.ADD) {
        uint256 previewShares = superVault.previewDeposit(assets);

        vm.prank(_getActor());
        uint256 shares = superVault.deposit(assets, _getActor());

        eq(
            previewShares,
            shares,
            ASSERTION_PREVIEW_DEPOSIT_MATCHES_EXECUTION
        );
    }

    /// @dev Action: mint shares for the current actor.
    function superVault_mint(
        uint256 shares
    ) public updateGhostsWithOpType(OpType.ADD) {
        vm.prank(_getActor());
        superVault.mint(shares, _getActor());
    }

    /// @dev Property: previewMint returns the correct amounts compared to executing a mint
    function superVault_mint_ASSERTION_PREVIEW_MINT_MATCHES_EXECUTION(
        uint256 shares
    ) public updateGhostsWithOpType(OpType.ADD) {
        uint256 previewMint = superVault.previewMint(shares);

        vm.prank(_getActor());
        uint256 assets = superVault.mint(shares, _getActor());

        eq(
            assets,
            previewMint,
            ASSERTION_PREVIEW_MINT_MATCHES_EXECUTION
        );
    }

    function superVault_invalidateNonce(bytes32 nonce) public asActor {
        superVault.invalidateNonce(nonce);
    }

    function superVault_redeem(
        uint256 shares
    ) public updateGhostsWithOpType(OpType.REMOVE) asActor {
        superVault.redeem(shares, _getActor(), _getActor());
    }

    function superVault_withdraw(
        uint256 assets
    ) public updateGhostsWithOpType(OpType.REMOVE) asActor {
        superVault.withdraw(assets, _getActor(), _getActor());
    }

    function superVault_requestRedeem(
        uint256 shares
    ) public updateGhostsWithOpType(OpType.REQUEST) asActor {
        superVault.requestRedeem(shares, _getActor(), _getActor());
    }

    function superVault_setOperator(
        uint256 entropy,
        bool approved
    ) public asActor {
        address operator = _getRandomActor(entropy);
        superVault.setOperator(operator, approved);
    }

    function _executeTransfer(
        uint256 entropy,
        uint256 value
    ) internal returns (TransferContext memory context) {
        address to = _getRandomActor(entropy);
        ISuperVaultStrategy.SuperVaultState
            memory stateSenderBefore = superVaultStrategy.getSuperVaultState(
                _getActor()
            );
        ISuperVaultStrategy.SuperVaultState
            memory stateRecipientBefore = superVaultStrategy.getSuperVaultState(
                to
            );

        vm.prank(_getActor());
        try superVault.transfer(to, value) {
            context.success = true;
            ISuperVaultStrategy.SuperVaultState
                memory stateSenderAfter = superVaultStrategy.getSuperVaultState(
                    _getActor()
                );
            ISuperVaultStrategy.SuperVaultState
                memory stateRecipientAfter = superVaultStrategy
                    .getSuperVaultState(to);

            context.senderAccumulatorSharesDelta =
                stateSenderBefore.accumulatorShares -
                stateSenderAfter.accumulatorShares;
            context.recipientAccumulatorSharesDelta =
                stateRecipientAfter.accumulatorShares -
                stateRecipientBefore.accumulatorShares;
            context.senderAccumulatorCostBasisDelta =
                stateSenderBefore.accumulatorCostBasis -
                stateSenderAfter.accumulatorCostBasis;
            context.recipientAccumulatorCostBasisDelta =
                stateRecipientAfter.accumulatorCostBasis -
                stateRecipientBefore.accumulatorCostBasis;
        } catch (bytes memory err) {
            context.expectedError = checkError(
                err,
                "ERC20InsufficientBalance(address,uint256,uint256)"
            );
        }
    }

    /// @dev Action: transfer shares from the current actor to a random actor.
    function superVault_transfer(
        uint256 entropy,
        uint256 value
    ) public updateGhostsWithOpType(OpType.TRANSFER) {
        _executeTransfer(entropy, value);
    }

    /// @dev Property: transfers of shares should transfer the exact amount of accumulatorShares to the recipient.
    function superVault_transfer_ASSERTION_TRANSFER_SHARES_CONSERVED(
        uint256 entropy,
        uint256 value
    ) public updateGhostsWithOpType(OpType.TRANSFER) {
        TransferContext memory context = _executeTransfer(entropy, value);
        if (context.success) {
            eq(
                context.senderAccumulatorSharesDelta,
                context.recipientAccumulatorSharesDelta,
                ASSERTION_TRANSFER_SHARES_CONSERVED
            );
        }
    }

    /// @dev Property: transfers of shares should transfer the exact amount of accumulatorCostBasis to the recipient.
    function superVault_transfer_ASSERTION_TRANSFER_COST_BASIS_CONSERVED(
        uint256 entropy,
        uint256 value
    ) public updateGhostsWithOpType(OpType.TRANSFER) {
        TransferContext memory context = _executeTransfer(entropy, value);
        if (context.success) {
            eq(
                context.senderAccumulatorCostBasisDelta,
                context.recipientAccumulatorCostBasisDelta,
                ASSERTION_TRANSFER_COST_BASIS_CONSERVED
            );
        }
    }

    /// @dev Property: _update should never revert in transfer unless balance is insufficient.
    function superVault_transfer_ASSERTION_UPDATE_SHOULD_NOT_REVERT_TRANSFER(
        uint256 entropy,
        uint256 value
    ) public updateGhostsWithOpType(OpType.TRANSFER) {
        TransferContext memory context = _executeTransfer(entropy, value);
        if (!context.success) {
            t(context.expectedError, ASSERTION_UPDATE_SHOULD_NOT_REVERT_TRANSFER);
        }
    }

    function _executeTransferFrom(
        uint256 entropyFrom,
        uint256 entropyTo,
        uint256 value
    ) internal returns (bool success, bool expectedError) {
        address from = _getRandomActor(entropyFrom);
        address to = _getRandomActor(entropyTo);

        vm.prank(_getActor());
        try superVault.transferFrom(from, to, value) {
            success = true;
        } catch (
            bytes memory err
        ) {
            expectedError =
                checkError(
                    err,
                    "ERC20InsufficientBalance(address,uint256,uint256)"
                ) ||
                checkError(
                    err,
                    "ERC20InsufficientAllowance(address,uint256,uint256)"
                );
        }
    }

    /// @dev Action: transfer shares on behalf of another actor.
    function superVault_transferFrom(
        uint256 entropyFrom,
        uint256 entropyTo,
        uint256 value
    ) public updateGhostsWithOpType(OpType.TRANSFER) {
        _executeTransferFrom(entropyFrom, entropyTo, value);
    }

    /// @dev Property: _update should never revert in transferFrom unless balance/allowance is insufficient.
    function superVault_transferFrom_ASSERTION_UPDATE_SHOULD_NOT_REVERT_TRANSFER_FROM(
        uint256 entropyFrom,
        uint256 entropyTo,
        uint256 value
    ) public updateGhostsWithOpType(OpType.TRANSFER) {
        (bool success, bool expectedError) = _executeTransferFrom(
            entropyFrom,
            entropyTo,
            value
        );
        if (!success) {
            t(
                expectedError,
                ASSERTION_UPDATE_SHOULD_NOT_REVERT_TRANSFER_FROM
            );
        }
    }

    /// @dev removed because signature components not fuzzable
    // function superVault_authorizeOperator(
    //     address controller,
    //     address operator,
    //     bool approved,
    //     bytes32 nonce,
    //     uint256 deadline,
    //     bytes memory signature
    // ) public asActor {
    //     superVault.authorizeOperator(
    //         controller,
    //         operator,
    //         approved,
    //         nonce,
    //         deadline,
    //         signature
    //     );
    // }
}
