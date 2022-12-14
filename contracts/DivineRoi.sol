// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

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
        uint256 totalDeposit;
        uint256 totalWithdrawed;
        uint256 remainedAmount;
        mapping(uint128 => Deposit) deposits;
    }

    struct ReferInfo{
        uint256[5] levelPeopleNum;
        uint256 referEarnings;
        uint256 withdrawed;
    }


    address public admin;
    mapping(address => DepositSet) private _depositInfo;
    mapping(address => ReferInfo) private _refers;
    mapping(address => address) private _referers;
    mapping(uint256 => address) addrFromCode;
    
    uint256 private _minDeposit;
    uint256 private _maxDeposit;
    address private _nft;
    uint256 private _fee;
    uint256 private _totalDeposit;


    AggregatorV3Interface private _priceFeed;

    uint256 _leaderNum;

    
    event DepositSuccess(address sender, uint256 amount);
    event SetReferer(address referer, address referee);
    event Withdrawed(address withdrawer, uint256 amount);
    event ReferalWithdrawed(address withdrawer, uint256 amount);

    constructor(){
        //_priceFeed = AggregatorV3Interface(0xAB594600376Ec9fD91F8e885dADF0CE036862dE0); //mainnet
        _priceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada); //mumbai testnet
        _minDeposit = 10*(1e18);
        _maxDeposit = 5000*(1e18);
        _fee = 5 * (1 ether);
    }

    /**
     *  @dev set nft address
     */
    function setNFT(address addr) external onlyOwner {
        _nft = addr;
    }

    /**
     *  @dev get nft address
     */
    function getNFT() public view returns (address){
        return _nft;
    }

    /**
     *  @dev set fee.
     */
    function setFee(uint8 fee) external onlyOwner {
        _fee = fee * (1 ether);
    }

    /**
     *  @dev set minimum limit of deposit.
     */
    function getFee() public view returns (uint256){
        return _fee;
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
     * @dev returns the amount of max deposit value in Matic
     */
    function getAllDeposit() public view returns (uint256){
        return (_totalDeposit);
    }

    /** 
     * @dev  deposit function
     */
    function deposit(uint256 referCode) external payable {
        uint256 minLimit = getMinDepositInMatic();
        uint256 maxLimit = getMaxDepositInMatic();
        require(msg.value > minLimit, "insufficient amount!");
        require(msg.value < maxLimit, "exceed the maximum amount!");
        uint128 newIdx = _depositInfo[_msgSender()].end;
        _depositInfo[_msgSender()].deposits[newIdx].amount = msg.value - _fee;
        _depositInfo[_msgSender()].deposits[newIdx].deposit_time = block.timestamp;
        _depositInfo[_msgSender()].end ++;
        _depositInfo[_msgSender()].totalDeposit += msg.value - _fee;
        _totalDeposit += msg.value;
        address addr = addrFromCode[referCode];
        if(addr != address(0)){
            refered(msg.sender, addr);
            _addReferalEarnings(addr, msg.value);
        }
        emit DepositSuccess(_msgSender(), msg.value);
        uint256 code;
        code = uint256(keccak256(abi.encodePacked(msg.sender))) % 100000000;
        if(addrFromCode[code] == address(0)) {
            addrFromCode[code] = msg.sender;
        }
        console.log(code);
    }

    /** 
     * @dev  Remove the expired deposits from depositInfo
     */
    function _updateDepositInfo(address addr) internal {
        uint128 idx = _depositInfo[addr].start;
        uint256 before120DaysTime = block.timestamp - (120 days) + (1 days);
        while(_depositInfo[addr].start < _depositInfo[addr].end && 
            _depositInfo[addr].deposits[idx].deposit_time < before120DaysTime) 
        {
            _depositInfo[addr].start ++;
            idx ++;
        }
    }

    /** 
     * @dev  returns the information of the deposit
     */
    function getDepositInfo(address addr, uint128 idx) public view returns (Deposit memory){
        return _depositInfo[addr].deposits[idx];
    }

    /** 
     * @dev  returns the amount of the totalDeposit
     */
    function getTotalDeposit(address addr) public view returns (uint256){
        return _depositInfo[addr].totalDeposit;
    }
    
    /** 
     * @dev  returns the amount of the withdrawal
     */
    function getWithdrawableBalance(address addr) public view returns (uint256){
        return calculateEarnings(addr) + _depositInfo[addr].remainedAmount;
    }
    
    /** 
     * @dev  returns the amount of the totalEarnings
     */
    function getTotalEarnings(address addr) public view returns (uint256){
        return _depositInfo[addr].totalWithdrawed + 
                _depositInfo[addr].remainedAmount + 
                calculateEarnings(addr) +
                _refers[addr].withdrawed +
                _refers[addr].referEarnings;
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
    function withdraw(uint256 amount) public {
        uint256 remainings = _depositInfo[_msgSender()].remainedAmount;
        uint256 earnings = calculateEarnings(_msgSender());
        require(remainings + earnings >= amount, "The amount exceed the earnings");
        payable (_msgSender()).transfer(amount);
        _depositInfo[_msgSender()].remainedAmount = remainings + earnings - amount;
        _updateDepositInfo(_msgSender());
        _depositInfo[_msgSender()].lastWithdrawTime = block.timestamp;
        _depositInfo[_msgSender()].totalWithdrawed += amount;
        emit Withdrawed(_msgSender(), amount);
    }
    
    

    /** 
     * @dev  returns the amount of earnings from the system
     */
    function calculateEarnings(address addr) public view returns (uint256){

        uint256 earnings = _calculateBasicBonus(addr);
        earnings += _calculateHolderBonus(addr);
        if(_nft != address(0)){
            earnings += _calculateNFTBonus(addr);
        }
        earnings += _calculateMilestoneBonus(addr);

        earnings += _calculateLeadershipBonus(addr);
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
        while(idx < _depositInfo[addr].end){
            uint256 lastWithdrawTime = _depositInfo[addr].lastWithdrawTime;
            uint256 earningDays = (currentTime - _depositInfo[addr].deposits[idx].deposit_time)/(1 days) + 1;
            if(earningDays > 120) earningDays = 120;
            if(_depositInfo[addr].deposits[idx].deposit_time < lastWithdrawTime){
                earningDays -= (lastWithdrawTime - _depositInfo[addr].deposits[idx].deposit_time)/(1 days)+1;
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
        while(idx < _depositInfo[addr].end){
            uint256 lastWithdrawTime = _depositInfo[addr].lastWithdrawTime;
            uint256 earningDays = (currentTime - _depositInfo[addr].deposits[idx].deposit_time)/(1 days) + 1;
            if(earningDays > 120) earningDays = 120;
            if(_depositInfo[addr].deposits[idx].deposit_time < lastWithdrawTime){
                earningDays -= (lastWithdrawTime - _depositInfo[addr].deposits[idx].deposit_time)/(1 days) + 1;
            }
            if(earningDays > (5 days)){
                bonus += _depositInfo[addr].deposits[idx].amount * (earningDays-5) / 200 ;
            }
            if(earningDays > (10 days)){
                bonus += _depositInfo[addr].deposits[idx].amount * (earningDays-10) / 200 ;
            }
            if(earningDays > (15 days)){
                bonus += _depositInfo[addr].deposits[idx].amount * (earningDays-15) / 200 ;
            }
            idx++;
        }
        return bonus;
    }

    /** 
     * @dev  returns the amount of earnings from nft bonus
     * double of basic bonus : 2%;
     */
    function _calculateNFTBonus(address addr) internal view returns(uint256){
        if(IERC721(_nft).balanceOf(addr) == 0) return 0;
        return 2 * _calculateBasicBonus(addr);
    }

    /** 
     * @dev  returns the amount of earnings from milestone bonus
     */

    function _calculateMilestoneBonus(address addr) internal view returns(uint256){
        if(_totalDeposit < 1000000 * (1 ether)) return 0;
        if(!_checkLeader(addr)) return 0;
        if(_leaderNum == 0) return 0;        
        return 20000 * (1 ether) / _leaderNum;
    }

    /** 
     * @dev  returns the amount of earnings from leadership bonus
     * same as basic bonus : 1%;
     */

    function _calculateLeadershipBonus(address addr) internal view returns(uint256){
        if(!_checkLeader(addr)) return 0;
        return _calculateBasicBonus(addr);
    }
    /** 
     * @dev  returns if the parameter address is the leader or not
     */

    function _checkLeader(address addr) internal view returns(bool){
       if(_refers[addr].levelPeopleNum[0] >= 10 && _refers[addr].levelPeopleNum[1] >= 10 ) return true;
       return false;
    }
    
    /** 
     * @dev  returns the amount of earnings from milestone bonus
     */
    function refered(address addr, address referer) internal {
        require(referer!= addr, "You can not refered by yourself!");
        require(_referers[addr] == address(0), "You are already refered by another");
        _referers[addr] = referer;
        address tmpAddr = referer;
        uint8 count;
        while(tmpAddr != address(0) && count<5){
            _refers[tmpAddr].levelPeopleNum[count] ++;
            count++;
            tmpAddr = _referers[tmpAddr];
        }
        emit SetReferer(addr, referer);
    }

    function _addReferalEarnings(address addr, uint256 amount) internal {
        address tmpAddr = addr;
        for (uint8 i =0; i< 5; i++){
            if(_refers[tmpAddr].levelPeopleNum[0] == 0) break;
            else{
               _refers[tmpAddr].referEarnings += amount * (10 - i *2)/100;
            }
            tmpAddr = _referers[tmpAddr];
        }
    }

    function withdrawReferalEarnings() external {
        require(_refers[msg.sender].referEarnings!=0, "You have no referal Earnings");
        payable(address(this)).transfer(_refers[msg.sender].referEarnings);
        emit ReferalWithdrawed(msg.sender, _refers[msg.sender].referEarnings);
        _refers[msg.sender].withdrawed += _refers[msg.sender].referEarnings;
        _refers[msg.sender].referEarnings = 0;
    }

    function getTeamNum(address addr) public view returns (uint256){
        return _refers[addr].levelPeopleNum[0] +
                _refers[addr].levelPeopleNum[1] +
                _refers[addr].levelPeopleNum[2] +
                _refers[addr].levelPeopleNum[3] +
                _refers[addr].levelPeopleNum[4]; 
    }

    function getReferalWithdraw(address addr) public view returns (uint256){
        return _refers[addr].referEarnings;
    }

    function getCodeFromAddr(address addr) public pure returns (uint256){
        uint256 code;
        code = uint256(keccak256(abi.encodePacked(addr))) % 100000000;
        return code;
    }

    function getAddrFromCode(uint256 code) public view returns (address){
        return addrFromCode[code];
    }
}
