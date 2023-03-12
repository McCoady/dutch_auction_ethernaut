// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "solmate/utils/LibString.sol";
import "./NFT.sol";

/// @title A dutch auction contract for NFT collections
/// @author mctoady.eth @traintesttoad
/// @notice practice implementation, not recommended for use in production
contract DutchAuction is NFT {
    using LibString for uint256;

    error AuctionEnded();
    error AuctionInit();
    error AuctionNotEnded();
    error AuctionNotStarted();
    error MaxWalletMint();
    error NothingToRefund();
    error SoldOut();
    error WrongPrice();

    struct MintInfo {
        uint256 mintPrice;
        uint256 amountMinted;
    }

    // Set where auction price starts, rests, price drop frequency and price drop amount
    uint256 public constant AUCTION_START_PRICE = 1 ether;
    uint256 public constant AUCTION_RESTING_PRICE = 0.1 ether;
    uint256 public constant AUCTION_PRICE_DROP_FREQ = 10 * 60;
    uint256 public constant AUCTION_PRICE_DROP_AMOUNT = 0.05 ether;
    uint256 public constant AUCTION_DURATION = AUCTION_DURATION;

    uint256 public auctionStartTime;
    uint256 public finalPaidPrice;

    bool private auctionInit;
    bool public auctionEnded;

    mapping(address => uint256) walletMints;
    mapping(address => MintInfo) userMintInfo;

    /// @notice Permit some functions to only be called if the auction has ended
    modifier onlyWhenAuctionEnded() {
        if (!auctionEnded) revert AuctionNotEnded();
        _;
    }

    /// @notice Permit some functions to only be called if the auction has not ended
    modifier onlyWhenAuctionNotEnded() {
        if (auctionEnded) revert AuctionEnded();
        _;
    }
    // init NFT max supply & max per wallet, ERC721 name & symbol
    constructor() NFT(500, 3) ERC721("Random NFT", "RAND") {}

    // allow users to check the price they paid & amount they've minted
    function getMintInfo() external view returns (MintInfo memory) {
        return userMintInfo[msg.sender];
    }

    /// @notice Calculate the current auction price
    /// @return price, current auction price in wei
    function calculatePrice() public view returns (uint256 price) {
        if (!auctionInit) revert AuctionNotStarted();

        if (auctionEnded) return finalPaidPrice;

        uint256 timeSinceStart = block.timestamp - auctionStartTime;
        uint256 numAuctionDrops = timeSinceStart / AUCTION_PRICE_DROP_FREQ;
        uint256 auctionPriceDrop = numAuctionDrops * AUCTION_PRICE_DROP_AMOUNT;

        if (auctionPriceDrop > AUCTION_START_PRICE - AUCTION_RESTING_PRICE) {
            price = 0.1 ether;
        } else {
            price = AUCTION_START_PRICE - auctionPriceDrop;
        }
    }

    /// @notice Mint an NFT from the auction
    /// @param _amount, number of NFTs to mint
    function mint(
        uint256 _amount
    ) external payable onlyWhenAuctionNotEnded nonReentrant {
        if (!auctionInit) revert AuctionNotStarted();
        if (
            msg.sender != owner() &&
            _amount + walletMints[msg.sender] > MAX_PER_WALLET
        ) revert MaxWalletMint();

        uint256 nextTokenId = totalSupply;
        uint256 newTotalSupply = nextTokenId + _amount;

        if (newTotalSupply > MAX_SUPPLY) revert SoldOut();

        uint256 _mintPrice = calculatePrice();
        if (msg.value < _mintPrice * _amount) revert WrongPrice();

        userMintInfo[msg.sender] = MintInfo(_mintPrice, _amount);
        walletMints[msg.sender] += _amount;

        totalSupply = newTotalSupply;
        if (totalSupply == MAX_SUPPLY) {
            finalPaidPrice = _mintPrice;
        }

        for (; nextTokenId < newTotalSupply; ++nextTokenId) {
            _mint(msg.sender, nextTokenId);
        }
        if (msg.value > _mintPrice * _amount) {
            uint256 refundDue = msg.value - _mintPrice * _amount;
            (bool sent, ) = msg.sender.call{value: refundDue}("");
            require(sent, "Failed to send Ether");
        }
    }

    /// @notice Refund eth if users mint price is higher than finalSalePrice
    function refund() external onlyWhenAuctionEnded {
        MintInfo memory _userInfo = userMintInfo[msg.sender];
        if (_userInfo.mintPrice <= AUCTION_RESTING_PRICE)
            revert NothingToRefund();

        uint256 refundDue = (_userInfo.mintPrice - finalPaidPrice) *
            _userInfo.amountMinted;
        (bool sent, ) = msg.sender.call{value: refundDue}("");
        require(sent, "Failed to send Ether");
    }

    /// @notice Set initial token URI and start auction
    /// @param _initialUri, the baseUri for minted tokens
    function initAuction(
        string calldata _initialUri
    ) external payable onlyOwner {
        if (auctionInit) revert AuctionInit();

        auctionStartTime = block.timestamp;
        uri = _initialUri;

        auctionInit = true;
    }

    /// @notice Allow anyone to end the auction if collection has minted out or timelimit has passed
    /// @dev Auction must be ended for refunds to begin and for owner to withdraw funds
    function endAuction() external onlyWhenAuctionNotEnded {
        if (
            totalSupply != MAX_SUPPLY &&
            block.timestamp < auctionStartTime + AUCTION_DURATION
        ) revert AuctionNotEnded();

        if (totalSupply != MAX_SUPPLY) {
            finalPaidPrice = AUCTION_RESTING_PRICE;
        }
        auctionEnded = true;
    }

    /// @notice Allow owner to withdraw funds after the uaction has ended
    /// @param _to, the address the owner wishes to withdraw the funds to
    /// @dev Only callable once the auction has ended
    function withdraw(
        address _to
    ) external payable onlyOwner onlyWhenAuctionEnded {
        uint256 totalFunds = totalSupply * finalPaidPrice;
        // necessary?
        if (totalFunds > address(this).balance) {
            totalFunds = address(this).balance;
        }
        (bool sent, ) = payable(_to).call{value: totalFunds}("");
        require(sent, "Failed to send Ether");
    }
}
