// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import './interfaces/IAggregator.sol';
import '../lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import '../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import '../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol';
import '../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import '../lib/openzeppelin-contracts/contracts/utils/Pausable.sol';
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";
contract IaesirPresale is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    struct User {
        address userAddress;
        uint256 amount;
    }

    IAggregator public aggregatorContract;
    uint256 public counterUserPhase0;
    uint256 public counterUserPhase1;
    uint256 public currentPhase;
    uint256 public usdPhase0;
    uint256 public usdPhase1;
    uint256 public tokensSoldPhase0;
    uint256 public tokensSoldPhase1;
    uint256 public thresholdToReferral;
    address public paymentToken;
    address public paymentWallet;
    uint256[][3] public phases;

    mapping(address => uint256) public userPositionPhase0;
    mapping(address => uint256) public userPositionPhase1;
    mapping(uint256 => User) public userPhase0;
    mapping(uint256 => User) public userPhase1;
    mapping(address => bool) public isWhitelisted;
    mapping(address => bytes) public referralCode;

    event TokensBought(address indexed user, uint256 indexed tokensBought, uint256 usdRaised, uint256 timestamp);

    constructor(uint256[][3] memory phases_, address paymentToken_, address paymentWallet_, address aggregatorContract_, uint256 thresholdToReferral_) Ownable(paymentWallet_) {
        paymentToken = paymentToken_;
        paymentWallet = paymentWallet_;
        aggregatorContract = IAggregator(aggregatorContract_);
        phases = phases_;
        thresholdToReferral = thresholdToReferral_;
    }

    function checkIfEnoughTokens(uint256 tokensToReceive) internal view {
        if (currentPhase == 0) if (tokensSoldPhase0 + tokensToReceive > phases[currentPhase][0]) revert("Phase 0 completed");
        else if (currentPhase == 1) if (tokensSoldPhase1 + tokensToReceive > phases[currentPhase][0]) revert("Phase 1 completed");
    }

    function checkPhaseEndingTime(uint256 phase_) public view {
        if (phase_ == 0) require(block.timestamp <= phases[phase_][2], "Phase0 ending time reached");
        else if (phase_ == 1) require (block.timestamp <= phases[phase_][2], "Phase1 ending time reached");
    }

    function buyWithStable(uint256 amount_) external whenNotPaused nonReentrant {
        require(amount_ > 0, 'Amount can not be zero');
        if (currentPhase == 0) require(isWhitelisted[msg.sender], "User not whitelisted");
        checkPhaseEndingTime(currentPhase);

        uint256 tokenAmountToReceive = amount_ * 1e6 / phases[currentPhase][1];

        checkIfEnoughTokens(tokenAmountToReceive);
       
        if (currentPhase == 0) {
            usdPhase0 += amount_;
            tokensSoldPhase0 += tokenAmountToReceive;
            uint256 position = userPositionPhase0[msg.sender];
            if (position == 0) {
                counterUserPhase0++;
                userPhase0[counterUserPhase0] = User({userAddress: msg.sender, amount: tokenAmountToReceive});
                userPositionPhase0[msg.sender] = counterUserPhase0;
            } else { 
                User memory previousData = userPhase0[position]; 
                userPhase0[position] = User({userAddress: msg.sender, amount: previousData.amount + tokenAmountToReceive});
            }
        } else { 
            usdPhase1 += amount_;
            tokensSoldPhase1 += tokenAmountToReceive;
            uint256 position = userPositionPhase1[msg.sender];
            if (position == 0) {
                counterUserPhase1++;
                userPhase1[counterUserPhase1] = User({userAddress: msg.sender, amount: tokenAmountToReceive});
                userPositionPhase1[msg.sender] = counterUserPhase1;
            } else { 
                User memory previousData = userPhase1[position];
                userPhase1[position] = User({userAddress: msg.sender, amount: previousData.amount + tokenAmountToReceive});
            }
        }

        IERC20(paymentToken).safeTransferFrom(msg.sender, paymentWallet, amount_);

        emit TokensBought(msg.sender, tokenAmountToReceive, amount_, block.timestamp);
    }

    function buyWithEther() external payable whenNotPaused nonReentrant {
        require(msg.value > 0, 'Amount can not be zero');
        if (currentPhase == 0) require(isWhitelisted[msg.sender], "User not whitelisted");
        checkPhaseEndingTime(currentPhase);

        uint256 usdAmount = msg.value * getLatestPrice() / 1e18; 
        uint256 tokenAmountToReceive = usdAmount * 1e6 / phases[currentPhase][1]; 

        checkIfEnoughTokens(tokenAmountToReceive);

        if (currentPhase == 0) {
            usdPhase0 += usdAmount;
            tokensSoldPhase0 += tokenAmountToReceive;
            uint256 position = userPositionPhase0[msg.sender];
            if (position == 0) {
                counterUserPhase0++;
                userPhase0[counterUserPhase0] = User({userAddress: msg.sender, amount: tokenAmountToReceive});
                userPositionPhase0[msg.sender] = counterUserPhase0;
            } else { 
                User memory previousData = userPhase0[position];
                userPhase0[position] = User({userAddress: msg.sender, amount: previousData.amount + tokenAmountToReceive});
            }
        } else { 
            usdPhase1 += usdAmount;
            tokensSoldPhase1 += tokenAmountToReceive;
            uint256 position = userPositionPhase1[msg.sender];
            if (position == 0) {
                counterUserPhase1++;
                userPhase1[counterUserPhase1] = User({userAddress: msg.sender, amount: tokenAmountToReceive});
                userPositionPhase1[msg.sender] = counterUserPhase1;
            } else { 
                User memory previousData = userPhase1[position];
                userPhase1[position] = User({userAddress: msg.sender, amount: previousData.amount + tokenAmountToReceive});
            }
        }

        (bool success, ) = paymentWallet.call{value: msg.value}('');
        require(success, 'Transfer fail.');

        emit TokensBought(msg.sender, tokenAmountToReceive, usdAmount, block.timestamp);
    }

    function generateReferralCode() public returns (bytes memory) {
        require(referralCode[msg.sender].length == 0, "Already generated code");

        // Check if user has invested more than referralThreshold within the 2 phases
        uint256 positionPhase0 = userPositionPhase0[msg.sender];
        User memory userDataPhase0 = userPhase0[positionPhase0];
        uint256 amountInPhase0 = userDataPhase0.amount * phases[0][1] / 1e6;
        uint256 positionPhase1 = userPositionPhase1[msg.sender];
        User memory userDataPhase1 = userPhase0[positionPhase1];
        uint256 amountInPhase1 = userDataPhase1.amount * phases[1][1] / 1e6;
        require(amountInPhase0 + amountInPhase1 >= thresholdToReferral, "Not invested minimum amount");

        bytes memory code = abi.encodePacked(msg.sender, block.number);
        referralCode[msg.sender] = code;
        return code;
    }

    function checkReferralCode() public view returns(bytes memory) {
        return referralCode[msg.sender];
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , uint256 updatedAt, ) = aggregatorContract.latestRoundData();
        if (updatedAt < block.timestamp - 2 hours) revert("Chainlink data is too old");
        price = (price * (10 ** 10));
        return uint256(price);
    }

    function setThresholdToReferral(uint256 newThreshold_) public onlyOwner() {
        thresholdToReferral = newThreshold_;
    }

    function pausePresale() public onlyOwner {
        _pause();
    }

    function unpausePresale() public onlyOwner {
        _unpause();
    }

    function whitelistUser(address user_, bool whitelist_) external onlyOwner {
        isWhitelisted[user_] = whitelist_;
    }

    function updatePhase(uint256 phaseIndex_, uint256 phaseMaxTokens_, uint256 phasePrice_, uint256 phaseEndTime_) external onlyOwner {
        phases[phaseIndex_][0] = phaseMaxTokens_;
        phases[phaseIndex_][1] = phasePrice_;
        phases[phaseIndex_][2] = phaseEndTime_;
    }

    function changePhases(uint256[][3] memory phases_) external onlyOwner {
        phases = phases_;
    }

    function setCurrentPhase(uint256 newPhase) public onlyOwner {
        currentPhase = newPhase;
    }

    function setCounterUserPhase0(uint256 counterUserPhase0_) public onlyOwner {
        counterUserPhase0 = counterUserPhase0_;
    }

    function setCounterUserPhase1(uint256 counterUserPhase1_) public onlyOwner {
        counterUserPhase1 = counterUserPhase1_;
    }

    function setusdPhase0(uint256 usdPhase0_) public onlyOwner {
        usdPhase0 = usdPhase0_;
    }

    function setusdPhase1(uint256 usdPhase1_) public onlyOwner {
        usdPhase1 = usdPhase1_;
    }

    function setTokensSoldPhase0(uint256 tokensSoldPhase0_) public onlyOwner {
        tokensSoldPhase0 = tokensSoldPhase0_;
    }

    function setTokensSoldPhase1(uint256 tokensSoldPhase1_) public onlyOwner {
        tokensSoldPhase1 = tokensSoldPhase1_;
    }

    function setPaymentToken(address paymentToken_) public onlyOwner {
        paymentToken = paymentToken_;
    }

    function setpaymentWallet(address paymentWallet_) public onlyOwner {
        paymentWallet = paymentWallet_;
    }

    function setUserPositionPhase0(address user_, uint256 position_) public onlyOwner {
        userPositionPhase0[user_] = position_;
    }

    function setUserPositionPhase1(address user_, uint256 position_) public onlyOwner {
        userPositionPhase1[user_] = position_;
    }

    function setUserPhase0(uint256 position_, address userAddress_, uint256 amount_) public onlyOwner {
        User memory user_ = User({userAddress: userAddress_, amount: amount_});
        userPhase0[position_] = user_;
    }

    function setUserPhase1(uint256 position_, address userAddress_, uint256 amount_) public onlyOwner {
        User memory user_ = User({userAddress: userAddress_, amount: amount_});
        userPhase1[position_] = user_;
    }
}   