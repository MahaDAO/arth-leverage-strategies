// SPDX-License-Identifier: GNU-3

pragma solidity ^0.8.0;

contract LeverageAccount {
  function callFn(
    address target,
    bytes4 sig,
    bytes memory data
  ) public returns (uint256 answer) {
    assembly {
      // move pointer to free memory spot
      let ptr := mload(0x40)
      // put function sig at memory spot
      mstore(ptr, sig)
      // append argument after function sig
      mstore(add(ptr, 0x04), data)

      let result := call(
        15000, // gas limit
        sload(target), // to addr. append var to _slot to access storage variable
        0, // not transfer any ether
        ptr, // Inputs are stored at location ptr
        0x24, // Inputs are 36 bytes long
        ptr, // Store output over input
        0x20
      ) // Outputs are 32 bytes long

      if eq(result, 0) {
        revert(0, 0)
      }

      answer := mload(ptr) // Assign output to answer var
      mstore(0x40, add(ptr, 0x24)) // Set storage pointer to new space
    }
  }
}
