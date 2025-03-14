// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/IaesirNFT.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}

contract IaesirNFTTest is Test {
    IaesirNFT public nft;
    MockERC20 public paymentToken;
    address public deployer = address(1);
    address public user = address(2);
    address public fundsReceiver = address(3);
    
    string public constant BASE_URI = "TestUri";
    uint256 public constant TOTAL_SUPPLY = 10_000;
    uint256 public constant MINT_PRICE = 1_000 ether;

    function setUp() public {
        vm.startPrank(deployer);
        paymentToken = new MockERC20();
        nft = new IaesirNFT("Iaesir NFT", "IASR", BASE_URI, TOTAL_SUPPLY, MINT_PRICE, address(paymentToken), fundsReceiver);
        vm.stopPrank();

        vm.startPrank(user);
        paymentToken.mint(100_000 * 1e18);
        vm.stopPrank();
    }

    function testDeployment() public view {
        assertEq(nft.name(), "Iaesir NFT");
        assertEq(nft.symbol(), "IASR");
        assertEq(nft.baseUri(), BASE_URI);
        assertEq(nft.totalSupply(), TOTAL_SUPPLY);
        assertEq(nft.mintPrice(), MINT_PRICE);
        assertEq(nft.paymentToken(), address(paymentToken));
        assertEq(nft.fundsReceiver(), fundsReceiver);
    }

    function testMintNFT() public {
        vm.startPrank(user);
        paymentToken.approve(address(nft), MINT_PRICE);
        vm.stopPrank();

        vm.startPrank(user);
        nft.mintNFT(1);
        vm.stopPrank();

        assertEq(nft.balanceOf(user), 1);
        assertEq(nft.ownerOf(0), user);
    }

    function testMintFailsIfSoldOut() public {
        vm.startPrank(user);
        paymentToken.approve(address(nft), MINT_PRICE * TOTAL_SUPPLY);
        vm.stopPrank();

        vm.startPrank(user);
        paymentToken.mint(MINT_PRICE * TOTAL_SUPPLY);
        nft.mintNFT(TOTAL_SUPPLY);
        vm.stopPrank();

        vm.expectRevert("Sold out");
        vm.prank(user);
        nft.mintNFT(1);
    }

    function testTokenURI() public {
        vm.startPrank(user);
        paymentToken.approve(address(nft), MINT_PRICE);
        nft.mintNFT(1);
        vm.stopPrank();

        string memory expectedUri = string(abi.encodePacked(BASE_URI, "0.json"));
        assertEq(nft.tokenURI(0), expectedUri);
    }
}