// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import '../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';

contract IaesirToken is ERC20 {
  uint256 _totalSupply = 1000000000 * 1e18;

  constructor(address distributorAddress_) ERC20('IAESIR Token', 'IASR') {
    _mint(distributorAddress_, _totalSupply);
  }
}