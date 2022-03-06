// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import {LeverageAccount, LeverageAccountFactory} from "./LeverageAccountFactory.sol";

// This Registry deploys new proxy instances through DSProxyFactory.build(address) and keeps a registry of owner => proxy
contract LeverageAccountRegistry {
  mapping(address => LeverageAccount) public accounts;
  LeverageAccountFactory public factory;

  constructor(address factory_) {
    factory = LeverageAccountFactory(factory_);
  }

  // deploys a new proxy instance
  // sets owner of proxy to caller
  function build() public returns (address payable account) {
    account = build(msg.sender);
  }

  // deploys a new proxy instance
  // sets custom owner of proxy
  function build(address owner) public returns (address payable account) {
    // Not allow new proxy if the user already has one and remains being the owner
    require(
      address(accounts[owner]) == address(LeverageAccount(address(0))) ||
        accounts[owner].canExecute(owner),
      "account exists"
    );

    account = factory.build(owner);
    accounts[owner] = LeverageAccount(account);
  }
}
