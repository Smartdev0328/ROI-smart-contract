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
        uint256 lastWithdrawTime;
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
    event Withdraw(address withdrawer, uint256 amount);

    constructor(address aggregatorAddr){
        _priceFeed = AggregatorV3Interface(aggregatorAddr);
        _minDeposit = 10*(1e18);
        _maxDeposit = 5000*(1e18);
    }

    /**
     *  @dev set minimum limit of deposit.
     */
    function setMinDeposit(uint256 minDeposit_) external onlyOwner {
        _minDeposit = minDeposit_ * (1e18);
    }

    /**
     * @dev set max limit of deposit.
     */
    function setMaxDeposit(uint256 maxDeposit_) public onlyOwner {
        _maxDeposit = maxDeposit_ * (1e18);
    }

    /**
     * @dev  returns the amount of min deposit value in Matic
     */
    function getMinDepositInMatic() public view returns (uint256){
        uint256 price = getLatestPrice();
        return (_minDeposit/price)*1e18;
    }

    /**
     * @dev returns the amount of max deposit value in Matic
     */
    function getMaxDepositInMatic() public view returns (uint256){
        uint256 price = getLatestPrice();
        return (_maxDeposit/price)*1e18;
    }

    /** 
     * @dev  deposit function
     */
    function deposit() external payable {
        uint256 minLimit = getMinDepositInMatic();
        uint256 maxLimit = getMaxDepositInMatic();
        require(msg.value > minLimit, "insufficient amount!");
        require(msg.value < maxLimit, "exceed the maximum amount!");
        uint128 newIdx = _depositInfo[_msgSender()].end;
        _depositInfo[_msgSender()].deposits[newIdx].amount = msg.value;
        _depositInfo[_msgSender()].deposits[newIdx].deposit_time = block.timestamp;
        _depositInfo[_msgSender()].end ++;
        emit DepositSuccess(_msgSender(), msg.value);
    }

    /** 
     * @dev  Remove the expired deposits from depositInfo
     */
    function _updateDepositInfo(address addr) internal {
        uint128 idx = _depositInfo[addr].start;
        uint256 before120DaysTime = block.timestamp - (120 days);
        while(_depositInfo[addr].deposits[idx].deposit_time != 0 && 
            _depositInfo[addr].deposits[idx].deposit_time < before120DaysTime) 
        {
            _depositInfo[addr].start ++;
        }
    }

    /** 
     * @dev  returns the information of the deposit
     */
    function getDepositInfo(address addr, uint128 idx) public view returns (Deposit memory){
        return _depositInfo[addr].deposits[idx];
    }
    
    /** 
     * @dev  returns the current Price of Matic in USD.
     */
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

    /** 
     * @dev  withdraw earnings from the system
     */
    function withdraw() public {
        uint256 earnings = calculateEarnings(_msgSender());
        console.log(earnings);
        payable (_msgSender()).transfer(earnings);
        _updateDepositInfo(_msgSender());
        _depositInfo[_msgSender()].lastWithdrawTime = block.timestamp;
        emit Withdraw(_msgSender(), earnings);
    }
    // function setReferer(address _referer) external {
    //     require(_referers[_msgSender()] == address(0), "Referer already set!");
    //     require(_msgSender() != _referer, "Referer already set!");
    //     //require(_deposits[_msgSender()].amount != 0, "You need to deposit before setReferer!");
    //     _referers[_msgSender()] = _referer;
    //     _refers[_referer] = _refers[_referer] + 1;
    //     emit SetReferer(_referer, _msgSender());
    // }

    /** 
     * @dev  returns the amount of earnings from the system
     */
    function calculateEarnings(address addr) public view returns (uint256){
        uint256 earnings = _calculateBasicBonus(addr);
        earnings += _calculateHolderBonus(addr);
        return earnings;
    }
    
    /** 
     * @dev  returns the amount of earnings from basic bonus
     * Once a user makes a deposit the system starts to accumulate 1% of the deposited amount for 120 days
     */
    function _calculateBasicBonus(address addr) internal view returns(uint256){
        uint256 currentTime = block.timestamp;
        uint128 idx = _depositInfo[addr].start;
        uint256 bonus = 0;
        while(idx <= _depositInfo[addr].end){
            uint256 lastWithdrawTime = _depositInfo[addr].lastWithdrawTime;
            uint256 earningDays = (currentTime - _depositInfo[addr].deposits[idx].deposit_time)/(1 days);
            if(earningDays > 120) earningDays = 120;
            if(_depositInfo[addr].deposits[idx].deposit_time < lastWithdrawTime){
                earningDays -= lastWithdrawTime - _depositInfo[addr].deposits[idx].deposit_time;
            }
            bonus += _depositInfo[addr].deposits[idx].amount * earningDays / 100;
            idx++;
        }
        return bonus;
    }

    /** 
     * @dev  returns the amount of earnings from Holder bonus
     * Users that hold without requesting a withdrawal earn 1.5% daily for all deposits that have not expired
     * The bonus accumulates at a rate of 0.5% every 5days to a maximum of 1.5%
     * This bonus resets back to zero upon request for withdrawal
     */
    function _calculateHolderBonus(address addr) internal view returns (uint256){
        uint256 currentTime = block.timestamp;
        uint128 idx = _depositInfo[addr].start;
        uint256 bonus = 0;
        while(idx <= _depositInfo[addr].end){
            uint256 lastWithdrawTime = _depositInfo[addr].lastWithdrawTime;
            uint256 earningDays = (currentTime - _depositInfo[addr].deposits[idx].deposit_time)/(1 days);
            if(earningDays > 120) earningDays = 120;
            if(_depositInfo[addr].deposits[idx].deposit_time < lastWithdrawTime){
                earningDays -= lastWithdrawTime - _depositInfo[addr].deposits[idx].deposit_time;
            }
            bonus += _depositInfo[addr].deposits[idx].amount * earningDays / 200 ;
            if(earningDays > (5 days)){
                bonus += _depositInfo[addr].deposits[idx].amount * (earningDays-5) / 200 ;
            }
            if(earningDays > (10 days)){
                bonus += _depositInfo[addr].deposits[idx].amount * (earningDays-10) / 200 ;
            }
            idx++;
        }
        return bonus;
    }
    // function _calculateHolderBonus() internal view returns(uint256){

    // }
    // function _withdraw(uint256 _amount) external {

    // }
}
