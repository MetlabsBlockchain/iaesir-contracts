// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/IaesirPresale.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract IaesirPresaleTest is Test { 
    IaesirPresale presale;
    address usdtAddress = 0x55d398326f99059fF775485246999027B3197955; // USDT BSC
    address aggregatorContract = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE; // PriceFeed BNB/USD en BSC
    address paymentWallet = 0x56E4CF839281f06c6B25a2037C5797C40D35fF2c;
    address randomRealUser = 0x4597C25089363788e75a32d0FbB5B334862570b6;
    address user = vm.addr(1);
    uint256[][3] phases;

    uint256 endTimePhase0 = 1752475465;
    uint256 endTimePhase1 = 1762478465;

    function setUp() public {
        phases[0] = [110_000_000 * 10**18, 40000, endTimePhase0];
        phases[1] = [200_000_00 * 10**18, 50000, endTimePhase1];

        vm.startPrank(paymentWallet);
        presale = new IaesirPresale(phases, usdtAddress, paymentWallet, aggregatorContract);
        vm.stopPrank();
    }

    function testInitialValues() public view {
        assertEq(presale.paymentToken(), usdtAddress);
        assertEq(presale.paymentWallet(), paymentWallet);
        assertEq(address(presale.aggregatorContract()), aggregatorContract);
    }

    function testOnlyOwnerCanPause() public {
        vm.startPrank(user);
        vm.expectRevert();
        presale.pausePresale();
        vm.stopPrank();
    }

    function testPausePresale() public {
        vm.startPrank(paymentWallet);
        presale.pausePresale();
        assertTrue(presale.paused());
        presale.unpausePresale();
        assertFalse(presale.paused());
        vm.stopPrank();
    }

    function testOnlyOwnerCanUnPause() public {
        vm.startPrank(user);
        vm.expectRevert();
        presale.unpausePresale();
        vm.stopPrank();
    }

    function testUnPausePresale() public {
        vm.startPrank(paymentWallet);
        presale.pausePresale();
        assertTrue(presale.paused());
        presale.unpausePresale();
        assertFalse(presale.paused());
        vm.stopPrank();
    }

    function testSetCurrentPhase() public {
        vm.startPrank(paymentWallet);
        presale.setCurrentPhase(1);
        assertEq(presale.currentPhase(), 1);
        presale.setCurrentPhase(0);
        assertEq(presale.currentPhase(), 0);
        vm.stopPrank();
    }

    function testOnlyOwnerSetCurrentPhase() public {
        vm.startPrank(user);
        vm.expectRevert();
        presale.setCurrentPhase(1);
        vm.stopPrank();
    }

    function testOnlyOwnerCanSetPhaseAttr() public {
        vm.startPrank(user);
        vm.expectRevert();
        presale.updatePhase(0, 1, 1, 1);
        vm.stopPrank();
    }

    function testOwnerCanSetPhaseAttr() public {
        vm.startPrank(paymentWallet);
        presale.updatePhase(0, 1, 1, 1);
        uint256 amount = presale.phases(0, 1);
        vm.assertEq(amount, 1);
        vm.stopPrank();
    }

    function testCanNotBuyWithStableIfNotWhitelisted() public {
        vm.startPrank(paymentWallet);
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        vm.expectRevert("User not whitelisted");
        presale.buyWithStable(amount);
        vm.stopPrank();
    }

    function testCanNotBuyWithStableAmount0() public {
        vm.startPrank(paymentWallet);
        uint256 amount = 0;
        IERC20(usdtAddress).approve(address(presale), amount);
        vm.expectRevert('Amount can not be zero');
        presale.buyWithStable(amount);
        vm.stopPrank();
    }

    function testCanNotBuyIfEndTimePhased() public {
        vm.startPrank(paymentWallet);
        presale.whitelistUser(paymentWallet, true);
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        vm.warp(endTimePhase0 + 1);
        vm.expectRevert('Phase0 ending time reached');
        presale.buyWithStable(amount);
        vm.stopPrank();
    }

    function testCanBuyWithStable() public {
        vm.startPrank(paymentWallet);
        presale.whitelistUser(paymentWallet, true);
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        presale.buyWithStable(amount);
        vm.stopPrank();
    }

    function testVariablesAreCorrectlyUpdateWhenBuyingWithStable() public {
        vm.startPrank(paymentWallet);
        presale.whitelistUser(paymentWallet, true);
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        uint256 usdPhase0Before = presale.usdPhase0();
        uint256 tokensSoldPhase0Before = presale.tokensSoldPhase0();
        presale.buyWithStable(amount);
        uint256 usdPhase0After = presale.usdPhase0();
        uint256 tokensSoldPhase0After = presale.tokensSoldPhase0();
        vm.assertTrue(usdPhase0After == usdPhase0Before + amount);
        vm.assertTrue(tokensSoldPhase0After > tokensSoldPhase0Before);
        vm.stopPrank();
    }

    function testCheckUserDataHasBeenCorrectlySetWhenBuyingWithStable() public {
        vm.startPrank(paymentWallet);
        presale.whitelistUser(paymentWallet, true);
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        
        uint256 counterPhase0Before = presale.counterUserPhase0();
        uint256 userPosition = 1;
        (address userAddress, uint256 amountTokens) = presale.userPhase0(userPosition);
        assert(userAddress == address(0));
        assert(amountTokens == 0);
        presale.buyWithStable(amount);
        (address userAddress2, uint256 amountTokens2) = presale.userPhase0(userPosition);
        assert(userAddress2 == paymentWallet);
        assert(amountTokens2 != 0);

        uint256 counterPhase0After = presale.counterUserPhase0();
        assert(counterPhase0After == counterPhase0Before + 1);
        
        vm.stopPrank();
    }

    function testCheckUserDataHasBeenCorrectlySetWhenBuyingWithStable2TimesSameUser() public {
        vm.startPrank(paymentWallet);
        presale.whitelistUser(paymentWallet, true);
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        
        // First buy
        uint256 buyExpectedAmount = 25 * 1e18;
        uint256 counterPhase0Before = presale.counterUserPhase0();
        uint256 userPosition = 1;
        (address userAddress, uint256 amountTokens) = presale.userPhase0(userPosition);
        assert(userAddress == address(0));
        assert(amountTokens == 0);
        presale.buyWithStable(amount);
        (address userAddress2, uint256 amountTokens2) = presale.userPhase0(userPosition);
        assert(userAddress2 == paymentWallet);
        assert(amountTokens2 == buyExpectedAmount);

        uint256 counterPhase0After = presale.counterUserPhase0();
        assert(counterPhase0After == counterPhase0Before + 1);

        // Second buy
        (address userAddress3, uint256 amountTokens3) = presale.userPhase0(userPosition);
        assert(userAddress3 == paymentWallet);
        assert(amountTokens3 == buyExpectedAmount);
        IERC20(usdtAddress).approve(address(presale), amount);
        presale.buyWithStable(amount);
        (address userAddress4, uint256 amountTokens4) = presale.userPhase0(userPosition);
        assert(userAddress4 == paymentWallet);
        assert(amountTokens4 == buyExpectedAmount * 2);

        uint256 counterPhase0After2 = presale.counterUserPhase0();
        assert(counterPhase0After2 == counterPhase0After);
        assert(counterPhase0After2 == 1);
        vm.stopPrank();
    }

    function testBuyWithStableCorrectlyPhase1() public {
        vm.startPrank(paymentWallet);
        presale.setCurrentPhase(1);
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        presale.buyWithStable(amount);
        vm.stopPrank();
    }

    function testVariablesAreCorrectlyUpdateWhenBuyingWithStablePhase1() public {
        vm.startPrank(paymentWallet);
        presale.setCurrentPhase(1);
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        uint256 usdPhase1Before = presale.usdPhase1();
        uint256 tokensSoldPhase1Before = presale.tokensSoldPhase1();
        presale.buyWithStable(amount);
        uint256 usdPhase0After = presale.usdPhase0();
        uint256 usdPhase1After = presale.usdPhase1();
        uint256 tokensSoldPhase1After = presale.tokensSoldPhase1();
        assertTrue(usdPhase0After == 0);
        vm.assertTrue(usdPhase1After == usdPhase1Before + amount);
        vm.assertTrue(tokensSoldPhase1After > tokensSoldPhase1Before);
        vm.stopPrank();
    }

    function testCheckUserDataHasBeenCorrectlySetWhenBuyingWithStablePhase1() public {
        vm.startPrank(paymentWallet);
        presale.setCurrentPhase(1);
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        
        uint256 counterPhase1Before = presale.counterUserPhase1();
        uint256 userPosition = 1;
        (address userAddress, uint256 amountTokens) = presale.userPhase1(userPosition);
        assert(userAddress == address(0));
        assert(amountTokens == 0);
        presale.buyWithStable(amount);
        (address userAddress2, uint256 amountTokens2) = presale.userPhase1(userPosition);
        assert(userAddress2 == paymentWallet);
        assert(amountTokens2 != 0);

        uint256 counterPhase0After = presale.counterUserPhase0();
        assert(counterPhase0After == 0);

        uint256 counterPhase1After = presale.counterUserPhase1();
        assert(counterPhase1After == counterPhase1Before + 1);
        
        vm.stopPrank();
    }

    function testCheckUserDataHasBeenCorrectlySetWhenBuyingWithStable2TimesSameUserPhase1() public {
        vm.startPrank(paymentWallet);
        presale.setCurrentPhase(1);
        presale.whitelistUser(paymentWallet, true);
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        
        // First buy
        uint256 buyExpectedAmount = 20 * 1e18;
        uint256 counterPhase1Before = presale.counterUserPhase1();
        uint256 userPosition = 1;
        (address userAddress, uint256 amountTokens) = presale.userPhase1(userPosition);
        assert(userAddress == address(0));
        assert(amountTokens == 0);
        presale.buyWithStable(amount);
        (address userAddress2, uint256 amountTokens2) = presale.userPhase1(userPosition);
        assert(userAddress2 == paymentWallet);
        assert(amountTokens2 == buyExpectedAmount);

        uint256 counterPhase1After = presale.counterUserPhase1();
        assert(counterPhase1After == counterPhase1Before + 1);

        // Second buy
        (address userAddress3, uint256 amountTokens3) = presale.userPhase1(userPosition);
        assert(userAddress3 == paymentWallet);
        assert(amountTokens3 == buyExpectedAmount);
        IERC20(usdtAddress).approve(address(presale), amount);
        presale.buyWithStable(amount);
        (address userAddress4, uint256 amountTokens4) = presale.userPhase1(userPosition);
        assert(userAddress4 == paymentWallet);
        assert(amountTokens4 == buyExpectedAmount * 2);

        uint256 counterPhase0After2 = presale.counterUserPhase0();
        assert(counterPhase0After2 == 0);

        uint256 counterPhase1After2 = presale.counterUserPhase1();
        assert(counterPhase1After2 == counterPhase1After);
        assert(counterPhase1After2 == 1);
        vm.stopPrank();
    }

    function testBuyWithEtherCorrectlyPhase0() public {
        vm.startPrank(paymentWallet);
        presale.whitelistUser(paymentWallet, true);
        uint256 amount = 1000000000000000; // 0.001 ether
        presale.buyWithEther{value: amount}();
        vm.stopPrank();
    }

    function testCheckUserDataHasBeenCorrectlySetWhenBuyingWithEther() public {
        vm.startPrank(paymentWallet);
        presale.whitelistUser(paymentWallet, true);
        uint256 amount = 1000000000000000; // 0.001 ether
       
        uint256 counterPhase0Before = presale.counterUserPhase0();
        uint256 userPosition = 1;
        (address userAddress, uint256 amountTokens) = presale.userPhase0(userPosition);
        assert(userAddress == address(0));
        assert(amountTokens == 0);
        presale.buyWithEther{value: amount}();
        (address userAddress2, uint256 amountTokens2) = presale.userPhase0(userPosition);
        assert(userAddress2 == paymentWallet);
        assert(amountTokens2 != 0);

        uint256 counterPhase0After = presale.counterUserPhase0();
        assert(counterPhase0After == counterPhase0Before + 1);
        
        vm.stopPrank();
    }

    function testCheckUserDataHasBeenCorrectlySetWhenBuyingWithEther2TimesSameUser() public {
        vm.startPrank(paymentWallet);
        presale.whitelistUser(paymentWallet, true);
        uint256 amount = 1000000000000000; // 0.001 ether
        
        // First buy
        uint256 counterPhase0Before = presale.counterUserPhase0();
        uint256 userPosition = 1;
        (address userAddress, uint256 amountTokens) = presale.userPhase0(userPosition);
        assert(userAddress == address(0));
        assert(amountTokens == 0);
        presale.buyWithEther{value: amount}();
        (address userAddress2, uint256 amountTokens2) = presale.userPhase0(userPosition);
        assert(userAddress2 == paymentWallet);
        assert(amountTokens2 != 0);

        uint256 counterPhase0After = presale.counterUserPhase0();
        assert(counterPhase0After == counterPhase0Before + 1);

        // Second buy
        (address userAddress3, uint256 amountTokens3) = presale.userPhase0(userPosition);
        assert(userAddress3 == paymentWallet);
        assert(amountTokens3 != 0);
        presale.buyWithEther{value: amount}();
        (address userAddress4, uint256 amountTokens4) = presale.userPhase0(userPosition);
        assert(userAddress4 == paymentWallet);
        assert(amountTokens4 == amountTokens2 * 2);

        uint256 counterPhase0After2 = presale.counterUserPhase0();
        assert(counterPhase0After2 == counterPhase0After);
        assert(counterPhase0After2 == 1);
        vm.stopPrank();
    }

    function testBuyWithEtherCorrectlyPhase1() public {
        vm.startPrank(paymentWallet);
        presale.setCurrentPhase(1);
        uint256 amount = 1000000000000000; // 0.001 ether
        presale.buyWithEther{value: amount}();
        vm.stopPrank();
    }

    function testUserCanBuyWithStableAndThenWithEther() public {
        vm.startPrank(paymentWallet);
        presale.whitelistUser(paymentWallet, true);

        // Buy Stable
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        
        uint256 counterPhase0Before = presale.counterUserPhase0();
        uint256 userPosition = 1;
        (address userAddress, uint256 amountTokens) = presale.userPhase0(userPosition);
        assert(userAddress == address(0));
        assert(amountTokens == 0);
        presale.buyWithStable(amount);
        (address userAddress2, uint256 amountTokens2) = presale.userPhase0(userPosition);
        assert(userAddress2 == paymentWallet);
        assert(amountTokens2 != 0);

        uint256 counterPhase0After = presale.counterUserPhase0();
        assert(counterPhase0After == counterPhase0Before + 1);

        // Buy Ether
        uint256 amountEther = 1000000000000000; // 0.001 ether
       
        (address userAddress3, uint256 amountTokens3) = presale.userPhase0(userPosition);
        assert(userAddress3 == paymentWallet);
        assert(amountTokens3 != 0);
        presale.buyWithEther{value: amountEther}();
        (address userAddress4, uint256 amountTokens4) = presale.userPhase0(userPosition);
        assert(userAddress4 == paymentWallet);
        assert(amountTokens4 > amountTokens3);

        uint256 counterPhase0After2 = presale.counterUserPhase0();
        assert(counterPhase0After2 == counterPhase0After);
        assert(counterPhase0After2 == 1);
        
        vm.stopPrank();
    }

    function testCanBuyWithStablePhase0AndThenEtherPhase1() public {
        vm.startPrank(paymentWallet);
        presale.whitelistUser(paymentWallet, true);

        // Buy Stable
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        
        uint256 counterPhase0Before = presale.counterUserPhase0();
        uint256 userPosition = 1;
        (address userAddress, uint256 amountTokens) = presale.userPhase0(userPosition);
        assert(userAddress == address(0));
        assert(amountTokens == 0);
        presale.buyWithStable(amount);
        (address userAddress2, uint256 amountTokens2) = presale.userPhase0(userPosition);
        assert(userAddress2 == paymentWallet);
        assert(amountTokens2 != 0);

        uint256 counterPhase0After = presale.counterUserPhase0();
        assert(counterPhase0After == counterPhase0Before + 1);
        
        presale.setCurrentPhase(1);

        // Buy Ether
        uint256 amountEther = 1000000000000000; // 0.001 ether
       
        (address userAddress3, uint256 amountTokens3) = presale.userPhase0(userPosition);
        assert(userAddress3 == paymentWallet);
        assert(amountTokens3 != 0);
        uint256 counterPhase1Before = presale.counterUserPhase1();
        presale.buyWithEther{value: amountEther}();
        (address userAddress4, uint256 amountTokens4) = presale.userPhase0(userPosition);
        assert(userAddress4 == paymentWallet);
        assert(amountTokens4 == amountTokens3);

        uint256 counterPhase0After2 = presale.counterUserPhase0();
        assert(counterPhase0After2 == counterPhase0After);
        assert(counterPhase0After2 == 1);

        uint256 counterPhase1After = presale.counterUserPhase1();
        assert(counterPhase1Before == 0);
        assert(counterPhase1After == 1);
        
        vm.stopPrank();
    }

    function test2UserDepositWhatHappenWithThird() public {
        vm.startPrank(paymentWallet);
        presale.whitelistUser(paymentWallet, true);

        // First User deposits
        uint256 amount = 1e18;
        IERC20(usdtAddress).approve(address(presale), amount);
        
        uint256 counterPhase0Before = presale.counterUserPhase0();
        uint256 userPosition = 1;
        (address userAddress, uint256 amountTokens) = presale.userPhase0(userPosition);
        assert(userAddress == address(0));
        assert(amountTokens == 0);
        presale.buyWithStable(amount);
        (address userAddress2, uint256 amountTokens2) = presale.userPhase0(userPosition);
        assert(userAddress2 == paymentWallet);
        assert(amountTokens2 != 0);

        uint256 counterPhase0After = presale.counterUserPhase0();
        assert(counterPhase0After == counterPhase0Before + 1);
        presale.whitelistUser(randomRealUser, true);
        vm.stopPrank();

        // Second user deposits
        vm.startPrank(randomRealUser);
        uint256 amount2 = 2e18;
        IERC20(usdtAddress).approve(address(presale), amount2);
        
        uint256 counterPhase0Before2 = presale.counterUserPhase0();
        uint256 userPosition2 = 2;
        (address userAddress3, uint256 amountTokens3) = presale.userPhase0(userPosition2);
        assert(userAddress3 == address(0));
        assert(amountTokens3 == 0);
        presale.buyWithStable(amount2);
        (address userAddress4, uint256 amountTokens4) = presale.userPhase0(userPosition2);
        assert(userAddress4 == randomRealUser);
        assert(amountTokens4 != 0);

        uint256 counterPhase0After2 = presale.counterUserPhase0();
        assert(counterPhase0After2 == counterPhase0Before + 2);
        assert(counterPhase0After2 == counterPhase0Before2 + 1);

        (address userAddress5, uint256 amountTokens5) = presale.userPhase0(userPosition);
        assert(userAddress5 == userAddress2);
        assert(amountTokens5 == amountTokens2);
        vm.stopPrank();
    
        // First user deposits again
        vm.startPrank(paymentWallet);
        uint256 amount3 = 3e18;
        IERC20(usdtAddress).approve(address(presale), amount3);
        
        uint256 counterPhase0Before3 = presale.counterUserPhase0();
        uint256 userPosition3 = 1;
        uint256 userPosition4 = 3;
        (address userAddress6, uint256 amountTokens6) = presale.userPhase0(userPosition3);
        (address userAddress7, uint256 amountTokens7) = presale.userPhase0(userPosition4);
        assert(userAddress6 == paymentWallet);
        assert(amountTokens6 != 0);
        assert(userAddress7 == address(0));
        assert(amountTokens7 == 0);
        presale.buyWithStable(amount3);
        (address userAddress8, uint256 amountTokens8) = presale.userPhase0(userPosition3);
        (address userAddress9, uint256 amountTokens9) = presale.userPhase0(userPosition4);
        assert(userAddress8 == paymentWallet);
        assert(amountTokens8 != 0);
        assert(userAddress9 == address(0));
        assert(amountTokens9 == 0);

        uint256 counterPhase0After3 = presale.counterUserPhase0();
        assert(counterPhase0After3 == counterPhase0Before3);

        // Check if amount has been added correct
        console.log("Amount", amountTokens8, amountTokens6  );
        assert(amountTokens8 == amountTokens6 * 4);
   
        vm.stopPrank();
    }

    // Setter functions
    function testSetCounterUserPhase0() public {
        vm.startPrank(paymentWallet);
        presale.setCounterUserPhase0(10);
        assertEq(presale.counterUserPhase0(), 10);
        vm.stopPrank();
    }

    function testSetCounterUserPhase1() public {
        vm.startPrank(paymentWallet);
        presale.setCounterUserPhase1(20);
        assertEq(presale.counterUserPhase1(), 20);
        vm.stopPrank();
    }

    function testSetUsdPhase0() public {
        vm.startPrank(paymentWallet);
        presale.setusdPhase0(1000);
        assertEq(presale.usdPhase0(), 1000);
        vm.stopPrank();
    }

    function testSetUsdPhase1() public {
        vm.startPrank(paymentWallet);
        presale.setusdPhase1(2000);
        assertEq(presale.usdPhase1(), 2000);
        vm.stopPrank();
    }

    function testSetTokensSoldPhase0() public {
        vm.startPrank(paymentWallet);
        presale.setTokensSoldPhase0(500);
        assertEq(presale.tokensSoldPhase0(), 500);
        vm.stopPrank();
    }

    function testSetTokensSoldPhase1() public {
        vm.startPrank(paymentWallet);
        presale.setTokensSoldPhase1(1000);
        assertEq(presale.tokensSoldPhase1(), 1000);
        vm.stopPrank();
    }

    function testSetPaymentToken() public {
        address newToken = 0x1234567890123456789012345678901234567890;
        vm.startPrank(paymentWallet);
        presale.setPaymentToken(newToken);
        assertEq(presale.paymentToken(), newToken);
        vm.stopPrank();
    }

    function testSetPaymentWallet() public {
        address newWallet = 0x9876543210987654321098765432109876543210;
        vm.startPrank(paymentWallet);
        presale.setpaymentWallet(newWallet);
        assertEq(presale.paymentWallet(), newWallet);
        vm.stopPrank();
    }

    function testSetUserPositionPhase0() public {
        vm.startPrank(paymentWallet);
        presale.setUserPositionPhase0(user, 5);
        assertEq(presale.userPositionPhase0(user), 5);
        vm.stopPrank();
    }

    function testSetUserPositionPhase1() public {
        vm.startPrank(paymentWallet);
        presale.setUserPositionPhase1(user, 7);
        assertEq(presale.userPositionPhase1(user), 7);
        vm.stopPrank();
    }

    function testSetUserPhase0() public {
        vm.startPrank(paymentWallet);
        presale.setUserPhase0(3, user, 1000);
        (address storedUser, uint256 storedAmount) = presale.userPhase0(3);
        assertEq(storedUser, user);
        assertEq(storedAmount, 1000);
        vm.stopPrank();
    }

    function testSetUserPhase1() public {
        vm.startPrank(paymentWallet);
        presale.setUserPhase1(4, user, 2000);
        (address storedUser, uint256 storedAmount) = presale.userPhase1(4);
        assertEq(storedUser, user);
        assertEq(storedAmount, 2000);
        vm.stopPrank();
    }
}