// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "hardhat/console.sol";

import "./AggregatorV3Interface.sol";

contract DivineRoi is Ownable {
    
    struct Deposit {
        uint256 amount;
        uint256 deposit_time;
    }

    struct DepositSet{
        uint128 start;
        uint128 end;
        mapping(uint128 => Deposit) deposits;
    }

    address public admin;
    mapping(address => DepositSet) private _depositInfo;
    uint256 private _minDeposit;
    uint256 private _maxDeposit;
    IERC721 private _nft;
    mapping(address => address) private _referers;
    mapping(address => uint256) private _refers;
    
    AggregatorV3Interface private _priceFeed;

    
    event DepositSuccess(address sender, uint256 amount);
    event SetReferer(address referer, address referee);

    constructor(address aggregatorAddr){
        _priceFeed = AggregatorV3Interface(aggregatorAddr);
        _minDeposit = 10*(1e18);
        _maxDeposit = 5000*(1e18);
    }

    function setMinDeposit(uint256 minDeposit_) external onlyOwner {
        _minDeposit = minDeposit_ * (1e18);
    }

    function setMaxDeposit(uint256 maxDeposit_) public onlyOwner {
        _maxDeposit = maxDeposit_ * (1e18);
    }

    function getMinDepositInMatic() public view returns (uint256){
        uint256 price = getLatestPrice();
        return (_minDeposit/price)*1e18;
    }

    function getMaxDepositInMatic() public view returns (uint256){
        uint256 price = getLatestPrice();
        return (_maxDeposit/price)*1e18;
    }

    function deposit() external payable {
        uint256 minLimit = getMinDepositInMatic();
        uint256 maxLimit = getMaxDepositInMatic();
        require(msg.value > minLimit, "insufficient amount!");
        require(msg.value < maxLimit, "exceed the maximum amount!");
        _updateDepositInfo(_msgSender()); // remove expired deposit before new Deposit.
        uint128 newIdx = _depositInfo[_msgSender()].end;
        _depositInfo[_msgSender()].deposits[newIdx].amount = msg.value;
        _depositInfo[_msgSender()].deposits[newIdx].deposit_time = block.timestamp;
        _depositInfo[_msgSender()].end ++;
        emit DepositSuccess(_msgSender(), msg.value);
    }

    function _updateDepositInfo(address addr) internal {
        uint128 idx = _depositInfo[addr].start;
        uint256 before120DaysTime = block.timestamp - (120 days);
        while(_depositInfo[addr].deposits[idx].deposit_time != 0 && 
            _depositInfo[addr].deposits[idx].deposit_time < before120DaysTime) 
        {
            _depositInfo[addr].start ++;
        }
    }

    function getDepositInfo(address addr, uint128 idx) public view returns (Deposit memory){
        return _depositInfo[addr].deposits[idx];
    }
    
    function getLatestPrice() public pure returns (uint256){
        return 1e18;
        //  (
        //     /*uint80 roundID*/,
        //     int price,
        //     /*uint startedAt*/,
        //     /*uint timeStamp*/,
        //     /*uint80 answeredInRound*/
        // ) = priceFeed.latestRoundData();
        // return price;
    }

    // function setReferer(address _referer) external {
    //     require(_referers[_msgSender()] == address(0), "Referer already set!");
    //     require(_msgSender() != _referer, "Referer already set!");
    //     //require(_deposits[_msgSender()].amount != 0, "You need to deposit before setReferer!");
    //     _referers[_msgSender()] = _referer;
    //     _refers[_referer] = _refers[_referer] + 1;
    //     emit SetReferer(_referer, _msgSender());
    // }

    // function _calculateBasicBonus() internal view returns(uint256){
    //     uint256 currentTime = block.timestamp;
    //     uint256 passedDays = (currentTime - deposits[_msgSender()].deposit_time)/(1 days);
    //     if(passedDays > 120) passedDays = 120;
    //     uint256 basicBonus = deposits[_msgSender()].amount * passedDays / 100;
    //     return basicBonus;
    // }

    // function _calculateHolderBonus() internal view returns(uint256){

    // }
    // function _withdraw(uint256 _amount) external {

    // }
}
