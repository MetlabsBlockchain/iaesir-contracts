// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import '../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract IaesirNFT is ERC721 {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    uint256 public tokenCounter;
    uint256 public totalSupply;
    uint256 public mintPrice;
    address public paymentToken;
    address public fundsReceiver;
    string public baseUri;

    event TokenMinted(address userAddress_, uint256 tokenId_);

    constructor(string memory name_, string memory symbol_, string memory baseUri_, uint256 totalSupply_, uint256 mintPrice_, address paymentToken_, address fundsReceiver_) ERC721(name_, symbol_) {
        baseUri = baseUri_;
        paymentToken = paymentToken_;
        totalSupply = totalSupply_;
        mintPrice = mintPrice_;
        paymentToken = paymentToken_;
        fundsReceiver = fundsReceiver_;
    }

    function mintNFT(uint256 amount_) external {
        require(tokenCounter + amount_ <= totalSupply, "Sold out");
        for (uint256 i = 0; i < amount_; i++) {
            IERC20(paymentToken).safeTransferFrom(msg.sender, fundsReceiver, mintPrice);

            uint256 tokenCounter_ = tokenCounter;
            tokenCounter++;
            _safeMint(msg.sender, tokenCounter_);

            emit TokenMinted(msg.sender, tokenCounter_);
        }
    }

    function tokenURI(uint256 tokenId) public view override virtual returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString(), ".json") : "";
    }

    function _baseURI() internal view override virtual returns (string memory) {
        return baseUri;
    }
}