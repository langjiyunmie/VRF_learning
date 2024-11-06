

pragma solidity ^0.8.28;

import {Script,console} from "lib/forge-std/src/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreatSubcription,AddConsumer,FundSubscription} from "script/Interactions.s.sol";

contract DeployRaffle is Script{    

    function run() external returns (Raffle,HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();//我们无法通过实例再创建出一个实例出来，所以不可以用 helperConfig
        AddConsumer addconsumer = new AddConsumer();
        if(config.subscriptionId == 0){
            CreatSubcription creatsubcription = new CreatSubcription();
            (config.vrfCoordinatorV2_5, config.subscriptionId ) = creatsubcription.createSubscription(config.vrfCoordinatorV2_5, config.account);
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinatorV2_5,config.subscriptionId,config.link,config.account);
            helperConfig.setConfig(block.chainid, config);//有点不太明白，为了持久化配置吗？？
        }
        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.subscriptionId,
            config.gasLane, // keyHash
            config.automationUpdateInterval,
            config.raffleEntranceFee,
            config.callbackGasLimit,
            config.vrfCoordinatorV2_5
        );
        vm.stopBroadcast();
        //下面函数有进行广播，不需要再次在这里进行，vm了。不用担心为什么改变了链上状态却没有进行vm
        addconsumer.addConsumer(address(raffle), config.vrfCoordinatorV2_5, config.subscriptionId, config.account);
        return (raffle, helperConfig);
    }

}