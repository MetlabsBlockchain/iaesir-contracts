// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {IaesirPresale} from "../src/IAesirPresale.sol";
import "forge-std/Test.sol";

contract DeployIaesirPresale is Script {
    uint256[][3] phases_;

    function run() external returns (IaesirPresale) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address usdtAddress_ = 0x55d398326f99059fF775485246999027B3197955; // USDT BSC
        address aggregatorContract_ = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE; // PriceFeed BNB/USD en BSC
        address paymentWallet_ = 0x56E4CF839281f06c6B25a2037C5797C40D35fF2c; 

        phases_[0] = [110_000_000  * 10**18, 40000, 47128000]; // @audit CAMBIAR A FINAL
        phases_[1] = [200_000_00  * 10**18, 5000, 47188000]; // @audit CAMBIAR A FINAL

        IaesirPresale presale = new IaesirPresale(phases_, usdtAddress_, paymentWallet_, aggregatorContract_);

        vm.stopBroadcast();
        return presale;
    }
}