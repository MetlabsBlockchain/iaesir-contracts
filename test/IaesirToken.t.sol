// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../src/IaesirToken.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";

contract IaesirTokenTest is Test {
    address deployer = vm.addr(1);
    address distributor = vm.addr(2);
    IaesirToken token;
    uint256 _totalSupply = 1000000000 * 1e18;

    function setUp() public {
        vm.startPrank(deployer);
        token = new IaesirToken(distributor);
        vm.stopPrank();
    }

    function testTotalSupply() public view {
        uint256 afterDeploymentSupply = token.totalSupply();
        assert(afterDeploymentSupply == _totalSupply);
    }

    function testMintCorrectly() public view {
        uint256 tokenBalance = IERC20(token).balanceOf(distributor);
        assert(tokenBalance == _totalSupply);
    }
}
