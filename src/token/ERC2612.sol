// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title ERC2612
 */
abstract contract ERC2612 is ERC20, IERC20Permit {
    // EIP712 domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;
    // EIP2612 permit typehash
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    mapping(address => uint256) public nonces;

    constructor(address _self) {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name())),
                keccak256("1"),
                block.chainid,
                _self
            )
        );
    }

    /**
     * @dev Allows to spend holder's unlimited amount by the specified spender according to EIP2612.
     * The function can be called by anyone, but requires having allowance parameters
     * signed by the holder according to EIP712.
     * @param _holder The holder's address.
     * @param _spender The spender's address.
     * @param _value Allowance value to set as a result of the call.
     * @param _deadline The deadline timestamp to call the permit function. Must be a timestamp in the future.
     * Note that timestamps are not precise, malicious miner/validator can manipulate them to some extend.
     * Assume that there can be a 900 seconds time delta between the desired timestamp and the actual expiration.
     * @param _v A final byte of signature (ECDSA component).
     * @param _r The first 32 bytes of signature (ECDSA component).
     * @param _s The second 32 bytes of signature (ECDSA component).
     */
    function permit(
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
    {
        _checkPermit(_holder, _spender, _value, _deadline, _v, _r, _s);
        _approve(_holder, _spender, _value);
    }

    /**
     * @dev Cheap shortcut for making sequential calls to permit() + transferFrom() functions.
     */
    function receiveWithPermit(address _holder, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s)
        public
        virtual
    {
        _checkPermit(_holder, _msgSender(), _value, _deadline, _v, _r, _s);

        // we don't make calls to _approve to avoid unnecessary storage writes
        // however, emitting ERC20 events is still desired
        emit Approval(_holder, _msgSender(), _value);
        emit Approval(_holder, _msgSender(), 0);

        _transfer(_holder, _msgSender(), _value);
    }

    /**
     * @dev Cheap shortcut for making sequential calls to permit() + transferFrom() functions for different amount/address.
     */
    function transferFromWithPermit(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        public
        virtual
    {
        _checkPermit(_from, _msgSender(), _value, _deadline, _v, _r, _s);

        // we don't make call to _approve to avoid unnecessary storage write
        // however, emitting ERC20 events is still desired
        emit Approval(_from, _msgSender(), _value);
        if (_value < type(uint256).max) {
            require(_value >= _amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(_from, _msgSender(), _value - _amount);
            }
        }

        _transfer(_from, _to, _amount);
    }

    function _checkPermit(
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        private
    {
        require(block.timestamp <= _deadline, "ERC2612: expired permit");

        uint256 nonce = nonces[_holder]++;
        bytes32 digest = ECDSA.toTypedDataHash(
            DOMAIN_SEPARATOR, keccak256(abi.encode(PERMIT_TYPEHASH, _holder, _spender, _value, nonce, _deadline))
        );

        require(_holder == ECDSA.recover(digest, _v, _r, _s), "ERC2612: invalid signature");
    }
}
