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
        uint256 referralAmount;
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
    uint256 public maxTokensReferrer;
    uint256 public maxTokensReferred;
    uint256 public rewardPercentageReferrer = 3; // 3%
    uint256 public rewardPercentageReferred = 3; // 3%
    address public paymentToken0;
    address public paymentToken1;
    address public paymentWallet;
    uint256[][3] public phases;

    mapping(address => uint256) public userPositionPhase0;
    mapping(address => uint256) public userPositionPhase1;
    mapping(uint256 => User) public userPhase0;
    mapping(uint256 => User) public userPhase1;
    mapping(address => bytes) public referralCode;
    mapping(bytes => address) public referralCodeToAddress;

    event TokensBought(address indexed user, uint256 indexed tokensBought, uint256 usdRaised, uint256 timestamp);
    event GenerateCode(address indexed user, bytes indexed code);

    constructor(uint256[][3] memory phases_, address paymentToken0_, address paymentToken1_, address paymentWallet_, address aggregatorContract_, uint256 thresholdToReferral_, uint256 maxTokensReferrer_, uint256 maxTokensReferred_) Ownable(paymentWallet_) {
        paymentToken0 = paymentToken0_;
        paymentToken1 = paymentToken1_;
        paymentWallet = paymentWallet_;
        aggregatorContract = IAggregator(aggregatorContract_);
        phases = phases_;
        thresholdToReferral = thresholdToReferral_;
        maxTokensReferrer = maxTokensReferrer_;
        maxTokensReferred = maxTokensReferred_;
    }

    function checkIfEnoughTokens(uint256 tokensToReceive) internal view {
        if (currentPhase == 0) if (tokensSoldPhase0 + tokensToReceive > phases[currentPhase][0]) revert("Phase 0 completed");
        else if (currentPhase == 1) if (tokensSoldPhase1 + tokensToReceive > phases[currentPhase][0]) revert("Phase 1 completed");
    }

    function checkPhaseEndingTime(uint256 phase_) public view {
        if (phase_ == 0) require(block.timestamp <= phases[phase_][2], "Phase0 ending time reached");
        else if (phase_ == 1) require (block.timestamp <= phases[phase_][2], "Phase1 ending time reached");
    }

    function buyWithStable(address paymentToken_, uint256 amount_, bytes memory referralCode_) external whenNotPaused nonReentrant {
        require(amount_ > 0, 'Amount can not be zero');
        require(paymentToken_ == paymentToken0 || paymentToken_ == paymentToken1, "Incorrect token");
        checkPhaseEndingTime(currentPhase);

        uint256 tokenAmountToReceive = amount_ * 1e6 / phases[currentPhase][1];

        checkIfEnoughTokens(tokenAmountToReceive);

        uint256 referralTokenAmountToReceiveReferrer;
        uint256 referralTokenAmountToReceiveReferred;
        bool isUsingReferralCode = (referralCode_.length != 0 && referralCodeToAddress[referralCode_] != address(0));
        if (isUsingReferralCode) {
            address codeCreator = checkReferralCodeCreator(referralCode_);
            require(codeCreator != msg.sender, "Can not use your own code");
            referralTokenAmountToReceiveReferrer = mulScale(tokenAmountToReceive, rewardPercentageReferrer, 100); // Rewards for referrer
            referralTokenAmountToReceiveReferred = mulScale(tokenAmountToReceive, rewardPercentageReferred, 100); // Rewards for referred
        }

        if (currentPhase == 0) {
            usdPhase0 += amount_;
            tokensSoldPhase0 += tokenAmountToReceive;

            // Update referred info
            uint256 position = userPositionPhase0[msg.sender];
            if (position == 0) { // Referred did not invest in this phase
                addNewUserPhase0(msg.sender, tokenAmountToReceive, referralTokenAmountToReceiveReferred, 0);
            } else { // Referred already invested in this phase
                updateExistingUserPhase0(position, tokenAmountToReceive, referralTokenAmountToReceiveReferred, 0);
            }

            if (isUsingReferralCode) {
                // Update referrer info
                address referrer = referralCodeToAddress[referralCode_];
                uint256 positionReferrer = userPositionPhase0[referrer];
                if (positionReferrer == 0) { // Refferer did not invest in this phase
                    addNewUserPhase0(referrer, 0, referralTokenAmountToReceiveReferrer, 1);
                } else { // Referrer already invested in this phase
                    updateExistingUserPhase0(positionReferrer, 0, referralTokenAmountToReceiveReferred, 1);
                }
            }

        } else { 
            usdPhase1 += amount_;
            tokensSoldPhase1 += tokenAmountToReceive;

            // Update referred info
            uint256 position = userPositionPhase1[msg.sender];
            if (position == 0) { // Referred did not invest in this phase
                addNewUserPhase1(msg.sender, tokenAmountToReceive, referralTokenAmountToReceiveReferred, 0);
            } else { // Referred already invested in this phase
                updateExistingUserPhase1(position, tokenAmountToReceive, referralTokenAmountToReceiveReferred, 0);
            }

            if(isUsingReferralCode) {
                // Update referred info
                address referrer = referralCodeToAddress[referralCode_];
                uint256 positionReferrer = userPositionPhase1[referrer];
                if (positionReferrer == 0) { // Referrer did not invest in this phase
                    addNewUserPhase1(referrer, 0, referralTokenAmountToReceiveReferrer, 1);
                } else { // Referrer already invested in this phase
                    updateExistingUserPhase1(positionReferrer, 0, referralTokenAmountToReceiveReferred, 1);
                }
            }
        }

        IERC20(paymentToken_).safeTransferFrom(msg.sender, paymentWallet, amount_);

        emit TokensBought(msg.sender, tokenAmountToReceive, amount_, block.timestamp);
    }

    function buyWithEther(bytes memory referralCode_) external payable whenNotPaused nonReentrant {
        require(msg.value > 0, 'Amount can not be zero');
        checkPhaseEndingTime(currentPhase);

        uint256 usdAmount = msg.value * getLatestPrice() / 1e18; 
        uint256 tokenAmountToReceive = usdAmount * 1e6 / phases[currentPhase][1]; 

        checkIfEnoughTokens(tokenAmountToReceive);

        uint256 referralTokenAmountToReceiveReferrer;
        uint256 referralTokenAmountToReceiveReferred;
        bool isUsingReferralCode = (referralCode_.length != 0 && referralCodeToAddress[referralCode_] != address(0));
        if (isUsingReferralCode) {
            address codeCreator = checkReferralCodeCreator(referralCode_);
            require(codeCreator != msg.sender, "Can not use your own code");
            referralTokenAmountToReceiveReferrer = mulScale(tokenAmountToReceive, rewardPercentageReferrer, 100); // Rewards for referrer
            referralTokenAmountToReceiveReferred = mulScale(tokenAmountToReceive, rewardPercentageReferred, 100); // Rewards for referred
        }

        if (currentPhase == 0) {
            usdPhase0 += usdAmount;
            tokensSoldPhase0 += tokenAmountToReceive;

            // Update referred info
            uint256 position = userPositionPhase0[msg.sender];
            if (position == 0) { // Referred did not invest in this phase
                addNewUserPhase0(msg.sender, tokenAmountToReceive, referralTokenAmountToReceiveReferred, 0);
            } else { // Referred already invested in this phase
                updateExistingUserPhase0(position, tokenAmountToReceive, referralTokenAmountToReceiveReferred, 0);
            }

            if (isUsingReferralCode) {
                // Update referrer info
                address referrer = referralCodeToAddress[referralCode_];
                uint256 positionReferrer = userPositionPhase0[referrer];
                if (positionReferrer == 0) { // Refferer did not invest in this phase
                    addNewUserPhase0(referrer, 0, referralTokenAmountToReceiveReferrer, 1);
                } else { // Referrer already invested in this phase
                    updateExistingUserPhase0(positionReferrer, 0, referralTokenAmountToReceiveReferred, 1);
                }
            }
        
        } else { 
            usdPhase1 += usdAmount;
            tokensSoldPhase1 += tokenAmountToReceive;

            // Update referred info
            uint256 position = userPositionPhase1[msg.sender];
            if (position == 0) { // Referred did not invest in this phase
                addNewUserPhase1(msg.sender, tokenAmountToReceive, referralTokenAmountToReceiveReferred, 0);
            } else { // Referred already invested in this phase
                updateExistingUserPhase1(position, tokenAmountToReceive, referralTokenAmountToReceiveReferred, 0);
            }

            if(isUsingReferralCode) {
                // Update referred info
                address referrer = referralCodeToAddress[referralCode_];
                uint256 positionReferrer = userPositionPhase1[referrer];
                if (positionReferrer == 0) { // Referrer did not invest in this phase
                    addNewUserPhase1(referrer, 0, referralTokenAmountToReceiveReferrer, 1);
                } else { // Referrer already invested in this phase
                    updateExistingUserPhase1(positionReferrer, 0, referralTokenAmountToReceiveReferred, 1);
                }
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
        referralCodeToAddress[code] = msg.sender;

        emit GenerateCode(msg.sender, code);

        return code;

        
    }

    function checkReferralCode(address user_) public view returns(bytes memory) {
        return referralCode[user_];
    }

    function checkReferralCodeCreator(bytes memory code) public view returns(address) {
        return referralCodeToAddress[code];
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , uint256 updatedAt, ) = aggregatorContract.latestRoundData();
        if (updatedAt < block.timestamp - 2 hours) revert("Chainlink data is too old");
        price = (price * (10 ** 10));
        return uint256(price);
    }

    function pausePresale() public onlyOwner {
        _pause();
    }

    function unpausePresale() public onlyOwner {
        _unpause();
    }

    function updatePhase(uint256 phaseIndex_, uint256 phaseMaxTokens_, uint256 phasePrice_, uint256 phaseEndTime_) external onlyOwner {
        phases[phaseIndex_][0] = phaseMaxTokens_;
        phases[phaseIndex_][1] = phasePrice_;
        phases[phaseIndex_][2] = phaseEndTime_;
    }

    function setThresholdToReferral(uint256 newThreshold_) public onlyOwner() {
        thresholdToReferral = newThreshold_;
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

    function setPaymentToken0(address paymentToken_) public onlyOwner {
        paymentToken0 = paymentToken_;
    }

    function setPaymentToken1(address paymentToken_) public onlyOwner {
        paymentToken1 = paymentToken_;
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

    function setUserPhase0(uint256 position_, address userAddress_, uint256 amount_, uint256 referralAmount_) public onlyOwner {
        User memory user_ = User({userAddress: userAddress_, amount: amount_, referralAmount: referralAmount_});
        userPhase0[position_] = user_;
    }

    function setUserPhase1(uint256 position_, address userAddress_, uint256 amount_, uint256 referralAmount_) public onlyOwner {
        User memory user_ = User({userAddress: userAddress_, amount: amount_, referralAmount: referralAmount_});
        userPhase1[position_] = user_;
    }

    function setMaxTokensReferrer(uint256 newValue_) public onlyOwner() {
        maxTokensReferrer = newValue_;
    }

    function setMaxTokensReferred(uint256 newValue_) public onlyOwner() {
        maxTokensReferred = newValue_;
    }

    function setRewardPercentageReferrer(uint256 newValue_) public onlyOwner() {
        rewardPercentageReferrer = newValue_;
    }

    function setRewardPercentageReferred(uint256 newValue_) public onlyOwner() {
        rewardPercentageReferred = newValue_;
    }

    function setAggregatorContract(address newContract_) public onlyOwner() {
        aggregatorContract = IAggregator(newContract_);
    }

    function mulScale (uint x, uint y, uint128 scale) internal pure returns (uint) {
        uint a = x / scale;
        uint b = x % scale;
        uint c = y / scale;
        uint d = y % scale;

        return a * c * scale + a * d + b * c + b * d / scale;
    }

    function addNewUserPhase0(address user_, uint256 tokenAmountToReceive_, uint256 referralTokenAmountToReceive_, uint8 type_) internal { // type 0 is referred, type 1 is referrer
        uint256 maxAmount;
        if (type_ == 0) maxAmount = maxTokensReferred;
        else maxAmount = maxTokensReferrer;

        require(referralTokenAmountToReceive_ <= maxAmount, "Limit for referred");

        counterUserPhase0++;
        userPhase0[counterUserPhase0] = User({userAddress: user_, amount: tokenAmountToReceive_, referralAmount: referralTokenAmountToReceive_});
        userPositionPhase0[user_] = counterUserPhase0;
    }

    function addNewUserPhase1(address user_, uint256 tokenAmountToReceive_, uint256 referralTokenAmountToReceive_, uint8 type_) internal {
        uint256 maxAmount;
        if (type_ == 0) maxAmount = maxTokensReferred;
        else maxAmount = maxTokensReferrer;

        require(referralTokenAmountToReceive_ <= maxAmount, "Limit for referred");

        counterUserPhase1++;
        userPhase1[counterUserPhase1] = User({userAddress: user_, amount: tokenAmountToReceive_, referralAmount: referralTokenAmountToReceive_});
        userPositionPhase1[user_] = counterUserPhase1;
    }

    function updateExistingUserPhase0(uint256 position, uint256 tokenAmountToAdd_, uint256 referralTokenAmountToAdd_, uint8 type_) internal {
        uint256 maxAmount;
        if (type_ == 0) maxAmount = maxTokensReferred;
        else maxAmount = maxTokensReferrer;

        User memory previousData = userPhase0[position]; 
        require(previousData.referralAmount + referralTokenAmountToAdd_ <= maxAmount, "Limit for referrer phase0");
        userPhase0[position] = User({userAddress: previousData.userAddress, amount: previousData.amount + tokenAmountToAdd_, referralAmount: previousData.referralAmount + referralTokenAmountToAdd_});
    }

    function updateExistingUserPhase1(uint256 position, uint256 tokenAmountToAdd_, uint256 referralTokenAmountToAdd_, uint8 type_) internal {
        uint256 maxAmount;
        if (type_ == 0) maxAmount = maxTokensReferred;
        else maxAmount = maxTokensReferrer;

        User memory previousData = userPhase1[position]; 
        require(previousData.referralAmount + referralTokenAmountToAdd_ <= maxAmount, "Limit for referrer phase1");
        userPhase1[position] = User({userAddress: previousData.userAddress, amount: previousData.amount + tokenAmountToAdd_, referralAmount: previousData.referralAmount + referralTokenAmountToAdd_});
    }
}   