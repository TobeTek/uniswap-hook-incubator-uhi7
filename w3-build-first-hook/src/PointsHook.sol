// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

contract PointsHook is BaseHook, ERC1155 {
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function _afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) internal override returns (bytes4, BalanceDelta) {
        // Mint points equal to 20% of the amount of ETH spent
        uint256 ethSpendAmount = uint256(int256(-delta.amount0()));
        uint256 pointsForSwap = ethSpendAmount / 5; // 20% of ETH received
        _assignPoints(key.toId(), hookData, pointsForSwap);
        return (BaseHook.afterAddLiquidity.selector, delta);
    }

    function uri(uint256) public view virtual override returns (string memory) {
        return "https://api.example.com/token/{id}";
    }

    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        // Make sure it's ETH -> Token swap
        if (!key.currency0.isAddressZero()) {
            return (BaseHook.afterSwap.selector, 0);
        }

        if (swapParams.zeroForOne == false) {
            return (BaseHook.afterSwap.selector, 0);
        }

        // Mint points equal to 20% of the amount of ETH spent
        uint256 ethSpendAmount = uint256(int256(-delta.amount0()));
        uint256 pointsForSwap = ethSpendAmount / 5; // 20% of ETH received
        _assignPoints(key.toId(), hookData, pointsForSwap);

        return (BaseHook.afterSwap.selector, 0);
    }

    function _assignPoints(
        PoolId poolId,
        bytes calldata hookData,
        uint256 points
    ) internal {
        if (points == 0) return;
        if (hookData.length == 0) return;
        address user = abi.decode(hookData, (address));

        if (user == address(0)) return;

        // Mint points to user
        uint256 poolIdUint = uint256(PoolId.unwrap(poolId));
        _mint(user, poolIdUint, points, "");
    }
}
