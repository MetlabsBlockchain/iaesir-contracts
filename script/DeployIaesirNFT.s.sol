// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {IaesirNFT} from "../src/IaesirNFT.sol";
import "forge-std/Test.sol";

contract DeployIaesirNFT is Script {

    function run() external returns (IaesirNFT) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        string memory name_ = "Iaesir NFT";
        string memory symbol_ = "IASR";
        string memory baseUri_ = "TestUri";
        uint256 totalSupply_ = 10_000;
        uint256 mintPrice_ = 1_000;
        address paymentToken_ = 0x55d398326f99059fF775485246999027B3197955; // USDT en BSC
        address fundsReceiver_ = 0x56E4CF839281f06c6B25a2037C5797C40D35fF2c; // @audit modify

        IaesirNFT nft = new IaesirNFT(name_, symbol_, baseUri_, totalSupply_, mintPrice_, paymentToken_, fundsReceiver_);

        vm.stopBroadcast();
        return nft;
    }
}