pragma solidity ^0.8.28;


import {Script,console} from "lib/forge-std/src/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CodeConstants} from "./HelperConfig.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {LinkToken} from "../test/Mocks/LinkToken.sol";
import {VRFCoordinatorV2_5Mock} from "lib/forge-std/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


contract CreatSubcription is Script{
    //订阅id 
    function createSubscription(address vrfCoordinatorV2_5, address account ) public returns(address,uint256){
        console.log("Creating subcriptionid on the chain: " ,block.chainid);
        vm.startBroadcast(account);
        uint256 subid = VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", subid);
        console.log("please update your HelperConfig");
        return (vrfCoordinatorV2_5,subid);
    }

    function createSubscriptionUsingConfig() public returns (address,uint256){
        HelperConfig helperConfig =  new HelperConfig();
        address vrfCoordinatorV2_5 = helperConfig.getConfigByChainId(block.chainid).vrfCoordinatorV2_5;
        address account = helperConfig.getConfigByChainId(block.chainid).account;
        createSubscription(vrfCoordinatorV2_5, account);
        
    }
    function run() external returns (address, uint256) {
        return createSubscriptionUsingConfig();
    }
}
//添加消费合约的地址
contract AddConsumer is Script{

    function addConsumer(address contractAddToVrf,address vrfCoordinator,uint256 subId,address account) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);


        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractAddToVrf);
        vm.stopBroadcast();

    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinatorV2_5;
        uint256 subid = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentlyDeployed,vrfCoordinator,subid,account);

    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }

}

//向订阅的VRF mock 合约添加使用资金

contract FundSubscription is CodeConstants,Script{
     uint96 public constant FUND_AMOUNT = 3 ether;
    
    function fundSubscription(address vrfCoordinator,uint256 subcriptionid,address link,address account) public {
        console.log("Funding subscription: ", subcriptionid);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        if(block.chainid == LOCAL_CHAIN_ID){
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subcriptionid, FUND_AMOUNT);
            vm.stopBroadcast();
        }else{
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subcriptionid));
            vm.stopBroadcast();
        }

    }

    function fundSubscriptionUsingConfig() public { //参照前端页面的时候的操作流程
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinatorV2_5;
        uint256 subcriptionid = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;
        address link = helperConfig.getConfig().link;

        if(subcriptionid == 0){
            CreatSubcription creatSubcription = new CreatSubcription();
            (address updateVrfCoordinator,uint256 updateSubcriptionid) = creatSubcription.run();
            vrfCoordinator = updateVrfCoordinator;
            subcriptionid = updateSubcriptionid;
            console.log("New SubId Created! ", subcriptionid, "VRF Address: ", vrfCoordinator);
        }
        fundSubscription(vrfCoordinator, subcriptionid, link, account);

    }


}


