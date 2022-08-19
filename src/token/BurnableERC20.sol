// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "./BaseERC20.sol";

/**
 * @title BurnableERC20
 */
abstract contract BurnableERC20 is BaseERC20 {
    /**
     * @dev Burns tokens from the caller.
     * @param _value amount of tokens to burn. Should be less than or equal to caller balance.
     */
    function burn(uint256 _value) external {
        _burn(msg.sender, _value);
    }
}
