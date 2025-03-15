// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {IaesirToken} from "../src/IaesirToken.sol";
import "forge-std/Test.sol";

contract DeployIaesirToken is Script {

    address distributor = vm.addr(2); // @audit CAMBIAR A FINAL

    // IaesirToken
    IaesirToken iaesirToken;
    address iaesirTokenAddress;

    function run() external returns (IaesirToken) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Iaesir Token
        iaesirToken = new IaesirToken(distributor);
        iaesirTokenAddress = address(iaesirToken);

        vm.stopBroadcast();
        return iaesirToken;
    }
}