// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MoltfessionsChain} from "../src/MoltfessionsChain.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        MoltfessionsChain chain = new MoltfessionsChain();
        
        console.log("MoltfessionsChain deployed to:", address(chain));
        console.log("Operator:", chain.operator());
        
        vm.stopBroadcast();
    }
}
