
pragma solidity ^0.8.28;

import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Test, console2} from "lib/forge-std/src/Test.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "lib/forge-std/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/Mocks/LinkToken.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test,CodeConstants{
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);
    
    uint256 subscriptionId;
    bytes32 gasLane;//keyhash
    uint256 automationUpdateInterval;//interval
    uint256 raffleEntranceFee;//entrance
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    LinkToken link;

    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;
    
    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle,helperConfig) = deployer.run();
        vm.deal(PLAYER,STARTING_USER_BALANCE);
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;//keyhash
        automationUpdateInterval = config.automationUpdateInterval;//interval
        raffleEntranceFee = config.raffleEntranceFee;//entrance
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        link = LinkToken(config.link);
        vm.startPrank(msg.sender);
        if(block.chainid == LOCAL_CHAIN_ID){
            link.mint(msg.sender,LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subscriptionId, LINK_BALANCE);
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();
    }

    function testRaffleInitializesInOpenState() public view {
       assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }
    //是告诉测试框架，接下来的操作应该会触发一个特定的错误,如果该错误没有发生，测试将失败。
    function testRaffleRevertsWHenYouDontPayEnought() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);//预期下面的操作会抛出这个事件的错误
        raffle.enterRaffle();
    }
    function testRaffleRecordsPlayerWhenTheyEnter() public {
        //arrange
        vm.prank(PLAYER);
        //act
        raffle.enterRaffle{value:raffleEntranceFee}();
        //vm.stopPrank();  如果后续没有需要换到测试用户
        //eq
        address playerRecord = raffle.getPlayer(0);
        assert(playerRecord == PLAYER);

    }

    function testEmitsEventOnEntrance() public{
        vm.prank(PLAYER);
        vm.expectEmit(true,false,false,false,address(raffle));
        emit RaffleEnter(PLAYER);//使用 vm.expectEmit 进行事件验证时，第一个索引参数 player 会与 PLAYER 进行比较，以确保它们相等。
        raffle.enterRaffle{value: raffleEntranceFee}();
    
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {

        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded ,) = raffle.checkUpkeep("");
        
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {

        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) =  raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public{

        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsFalse() public{
        uint256 currentbalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentbalance, numPlayers, rState)
        );//当希望revert对象的时候，应该保持初识化状态，而不是根据已经实例化的对象去获取数据
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public {
      // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act
        vm.recordLogs();//这个函数的作用是告诉虚拟机开始记录从此刻起发生的所有事件日志。会读取整个合约的事件状态
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();//获取从调用 vm.recordLogs(); 之后到调用 vm.getRecordedLogs(); 之间所有记录的事件日志
        bytes32 requestId = entries[1].topics[1];//entries 是日志条目，emit几次事件就会生成几个事件条目，topics就是主题的意思，即在事件参数中使用 indexed，没有使用indexed参数的会被存在事件data部分
        // entries[1].topics[1]; 第二个事件条目的第二个主题
        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // 0 = open, 1 = calculating
        //enum 结构中，进行uint类型转换，直接对应了枚举变量里面的索引。
    }

    modifier raffleEnter(){
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }
    //因为我们部署了mock合约进行本地测试，测试网上是存在提供VRF的合约的。
    modifier skipFork(){
        if(block.chainid == 31337){
            return;//终止测试
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public raffleEnter skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(0, address(raffle));
        
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(1, address(raffle));
    

    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnter skipFork{
        address expectedWinner = address(1);

        uint256 additionEntrances = 3;
        uint256 startingIndex = 1;

        for(uint256 i = startingIndex; i < startingIndex + additionEntrances; i++){
            address player = address(uint160(i));//以太坊地址是 160 位的，这一点在以太坊的设计中是固定的
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: raffleEntranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[1].topics[1]); //logBytes32 方法用于打印 bytes32 类型的值。
        bytes32 requestId = entries[1].topics[1];//这里说明了预定的中奖者只能是 address(1), 经过了 enteRaffle函数释放事件，那么之后就是执行 performUpkeep函数，那么第一个执行者是 address(1)，所以释放的requestId 就是有关于address(1),是没有经过筛选直接调用的mock合约的函数

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(uint256(requestId),address(raffle));

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = raffleEntranceFee * (additionEntrances + 1);
        
        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);

    }
}

