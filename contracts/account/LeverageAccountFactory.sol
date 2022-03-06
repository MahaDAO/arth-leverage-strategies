// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LeverageAccount.sol";

// LeverageAccountFactory
// This factory deploys new proxy instances through build()
// Deployed proxy addresses are logged
contract LeverageAccountFactory {
  event Created(address indexed sender, address indexed owner, address account);
  mapping(address => bool) public isAccount;

  // deploys a new proxy instance
  // sets owner of proxy to caller
  function build() public returns (address payable account) {
    account = build(msg.sender);
  }

  // deploys a new proxy instance
  // sets custom owner of proxy
  function build(address owner) public returns (address payable account) {
    account = payable(address(new LeverageAccount(owner)));
    emit Created(msg.sender, owner, address(account));
    isAccount[account] = true;
  }
}
