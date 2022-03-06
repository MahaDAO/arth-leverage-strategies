// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract DelegateCaller {
  /**
   * @dev a helper function to execute a delegate call to another contract
   */
  function execute(address _target, bytes memory _data) internal returns (bytes memory response) {
    require(_target != address(0), "DelegateCaller: address-required");

    // call contract in current context
    assembly {
      let succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
      let size := returndatasize()

      response := mload(0x40)
      mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
      mstore(response, size)
      returndatacopy(add(response, 0x20), 0, size)

      switch iszero(succeeded)
      case 1 {
        // throw if delegatecall failed
        revert(add(response, 0x20), size)
      }
    }
  }
}
