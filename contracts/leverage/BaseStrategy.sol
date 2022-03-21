// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseStrategy {
  IERC20 public immutable arth;
  address private me;

  bytes4 private constant SELECTOR = 0x095ea7b3;

  constructor(address _arth) {
    arth = IERC20(_arth);
    me = address(this);
  }

  function run() public {
    bytes memory data = abi.encodeWithSelector(SELECTOR, me, 256000);
    _callFn(address(arth), data);
    arth.approve(msg.sender, 111);
  }

  function _callFn(address target, bytes memory _data) internal returns (bytes memory response) {
    // call contract in current context
    assembly {
      let succeeded := delegatecall(sub(gas(), 5000), target, add(_data, 0x20), mload(_data), 0, 0)
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
