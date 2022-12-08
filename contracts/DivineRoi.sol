// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "hardhat/console.sol";

import "./AggregatorV3Interface.sol";

contract DivineRoi is Ownable {
    address public admin;
    uint256 public minDeposit;
    uint256 public maxDeposit;
    IERC721 public nft;
    mapping(address => Deposit) deposits;
    mapping(address => address) referers;
    mapping(address => uint256) refers;
    AggregatorV3Interface priceFeed;

    struct Deposit {
        uint256 amount;
        uint256 deposit_time;
    }

    event DepositSuccess(address sender, uint256 amount);
    event SetReferer(address referer, address referee);

    constructor(){
        admin = _msgSender();
        priceFeed = AggregatorV3Interface(0xAB594600376Ec9fD91F8e885dADF0CE036862dE0);
        minDeposit = 10*(1e18);
        maxDeposit = 5000*(1e18);
    }

    modifier onlyAdmin {
        require(_msgSender() == admin, "only admin allowed");
        _;
    }

    function setMinDeposit(uint256 _amount) public onlyAdmin {
        minDeposit = _amount * (1e18);
    }

    function setMaxDeposit(uint256 _amount) public onlyAdmin {
        maxDeposit = _amount * (1e18);
    }

    function deposit() external payable {
        uint256 price = getLatestPrice();
        require(msg.value > (minDeposit/price)*1e18, "insufficient amount!");
        require(msg.value < (maxDeposit/price)*1e18, "exceed the maximum amount!");
        deposits[_msgSender()].amount = msg.value;
        deposits[_msgSender()].deposit_time = block.timestamp;
        console.log("deposit_amount:", msg.value);
        console.log("msg_sender:", _msgSender());
        emit DepositSuccess(_msgSender(), msg.value);
    }

    function getLatestPrice() internal pure returns (uint256){
        return 10**18;
        //  (
        //     /*uint80 roundID*/,
        //     int price,
        //     /*uint startedAt*/,
        //     /*uint timeStamp*/,
        //     /*uint80 answeredInRound*/
        // ) = priceFeed.latestRoundData();
        // return price;
    }

    function setReferer(address _referer) external {
        require(referers[_msgSender()] == address(0), "Referer already set!");
        require(_msgSender() != _referer, "Referer already set!");
        require(deposits[_msgSender()].amount != 0, "You need to deposit before setReferer!");
        referers[_msgSender()] = _referer;
        refers[_referer] = refers[_referer] + 1;
        emit SetReferer(_referer, _msgSender());
    }

    function _calculateBasicBonus() internal view returns(uint256){
        uint256 currentTime = block.timestamp;
        uint256 passedDays = (currentTime - deposits[_msgSender()].deposit_time)/(1 days);
        if(passedDays > 120) passedDays = 120;
        uint256 basicBonus = deposits[_msgSender()].amount * passedDays / 100;
        return basicBonus;
    }

    // function _calculateHolderBonus() internal view returns(uint256){

    // }
    // function _withdraw(uint256 _amount) external {

    // }
}
