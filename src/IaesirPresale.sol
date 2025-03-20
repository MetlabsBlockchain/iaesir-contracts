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
    address public paymentToken;
    address public paymentWallet;
    uint256[][3] public phases;

    mapping(address => uint256) public userPositionPhase0;
    mapping(address => uint256) public userPositionPhase1;
    mapping(uint256 => User) public userPhase0;
    mapping(uint256 => User) public userPhase1;
    mapping(address => bool) public isWhitelisted;

    event TokensBought(address indexed user, uint256 indexed tokensBought, uint256 usdRaised, uint256 timestamp);

    constructor(uint256[][3] memory phases_, address paymentToken_, address paymentWallet_, address aggregatorContract_) Ownable(paymentWallet_) {
        paymentToken = paymentToken_;
        paymentWallet = paymentWallet_;
        aggregatorContract = IAggregator(aggregatorContract_);
        phases = phases_;
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
                User memory previousData = userPhase0[counterUserPhase0];
                 console.log("IM HERE", previousData.userAddress, previousData.amount);
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
                User memory previousData = userPhase1[counterUserPhase1];
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
                User memory previousData = userPhase0[counterUserPhase0];
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
                User memory previousData = userPhase1[counterUserPhase1];
                userPhase1[position] = User({userAddress: msg.sender, amount: previousData.amount + tokenAmountToReceive});
            }
        }

        (bool success, ) = paymentWallet.call{value: msg.value}('');
        require(success, 'Transfer fail.');

        emit TokensBought(msg.sender, tokenAmountToReceive, usdAmount, block.timestamp);
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorContract.latestRoundData();
        price = (price * (10 ** 10));
        return uint256(price);
    }

    function pausePresale() public onlyOwner {
        _pause();
    }

    function unpausePresale() public onlyOwner {
        _unpause();
    }

    function setCurrentPhase(uint256 newPhase) public onlyOwner {
        currentPhase = newPhase;
    }

    function whitelistUser(address user_, bool whitelist_) external onlyOwner {
        isWhitelisted[user_] = whitelist_;
    }

    function updatePhase(uint256 phaseIndex_, uint256 phaseMaxTokens_, uint256 phasePrice_, uint256 phaseEndTime_) external onlyOwner {
        phases[phaseIndex_][0] = phaseMaxTokens_;
        phases[phaseIndex_][1] = phasePrice_;
        phases[phaseIndex_][2] = phaseEndTime_;
    }
}   