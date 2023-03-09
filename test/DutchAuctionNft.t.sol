// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/DutchAuctionNft.sol";

contract DutchAuctionTest is Test {
    DutchAuctionNft dan;

    address alice = makeAddr("alice");

    function setUp() public {
        dan = new DutchAuctionNft();
    }

    function testConstants() public {
        uint256 maxSupply = dan.MAX_SUPPLY();
        assertEq(maxSupply, 500);
        uint256 maxPerWallet = dan.MAX_PER_WALLET();
        assertEq(maxPerWallet, 3);
    }

    /*
    Token URI Tests
    */
    function testSetBaseURI() public {
        dan.setBaseURI("https://www.test.org/");
        assertEq(dan.uri(), "https://www.test.org/");
    }

    function testChangeBaseURIAfterInit() public {
        initAuction();
        dan.setBaseURI("https://difftest.org/");
        assertEq(dan.uri(), "https://difftest.org/");
    }

    function testCannotSetBaseURINonOwner() public {
        startHoax(alice);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        dan.setBaseURI("https://naughtyhacker.com/");
    }

    function testTokenURI() public {
        initAuction();
        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 1 ether}(1);
        assertEq(dan.balanceOf(alice), 1);
        assertEq(dan.tokenURI(0), "https://www.test.org/0");
    }

    /*
    Auction Init Tests
    */

    function testInitAuction() public {
        initAuction();
        uint256 startTime = dan.auctionStartTime();
        assertEq(startTime, block.timestamp);
        assertEq(dan.uri(), "https://www.test.org/");
    }

    function testCannotInitAuctionTwice() public {
        initAuction();
        uint256 startTime = dan.auctionStartTime();
        assertEq(startTime, block.timestamp);
        vm.expectRevert(DutchAuctionNft.AuctionInit.selector);
        initAuction();
    }

    function testCannotInitAuctionNonOwner() public {
        startHoax(alice);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        initAuction();
    }

    /*
    Calculate Price tests
    */
    function testInitThenCalcPrice() public {
        initAuction();
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
    }

    function testCalcPriceAfterTenMins() public {
        initAuction();
        vm.warp(10 * 60 + 1);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 0.95 ether);
    }

    function testCalcPriceAfterThreeeHours() public {
        initAuction();
        vm.warp(3 * 60 * 60 + 1);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 0.1 ether);
    }

    function testCalcPriceBeforeThreeeHours() public {
        initAuction();
        vm.warp(3 * 60 * 60 - 1);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 0.15 ether);
    }

    function testCalcPriceNotLowerThenEndPrice() public {
        initAuction();
        vm.warp(5 * 60 * 60);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 0.1 ether);
    }

    /*
    Mint Test
    */
    function testMintOne() public {
        initAuction();
        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 1 ether}(1);
        assertEq(dan.balanceOf(alice), 1);
    }

    function testMintThree() public {
        initAuction();
        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 3 ether}(3);
        assertEq(dan.balanceOf(alice), 3);
    }

    function testMintOneHigherValueSent() public {
        initAuction();
        startHoax(alice);
        vm.warp(10 * 60 + 1);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 0.95 ether);

        uint256 aliceBalance = alice.balance;
        dan.mint{value: 1 ether}(1);
        assertEq(dan.balanceOf(alice), 1); 
        assertEq(alice.balance, aliceBalance - 0.95 ether);    
    }

    function testMintThreeHigherValueSent() public {
        initAuction();
        startHoax(alice);
        vm.warp(10 * 60 + 1);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 0.95 ether);

        uint256 aliceBalance = alice.balance;
        dan.mint{value: 3 ether}(3);
        assertEq(dan.balanceOf(alice), 3); 
        assertEq(alice.balance, aliceBalance - 2.85 ether);    
    }

    function testMintThreeInTwoTx() public {
        initAuction();
        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 1 ether}(1);
        assertEq(dan.balanceOf(alice), 1);
        dan.mint{value: 2 ether}(2);
        assertEq(dan.balanceOf(alice), 3);        
    }

    function testCannotMintFourInOneTx() public {
        initAuction();
        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        vm.expectRevert(DutchAuctionNft.MaxWalletMint.selector);
        dan.mint{value: 4 ether}(4);
    }
    function testCannotMintFourInTwoTx() public {
        initAuction();
        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 2 ether}(2);
        assertEq(dan.balanceOf(alice), 2);
        vm.expectRevert(DutchAuctionNft.MaxWalletMint.selector);
        dan.mint{value: 2 ether}(2);
    }

    function testMintOut() public {
        initAuction();
        for (uint256 i = 0; i < 500; i++) {
            dan.mint{value: 1 ether}(1);
        }
        assertEq(dan.balanceOf(address(this)), 500);
        vm.expectRevert(DutchAuctionNft.SoldOut.selector);
        dan.mint{value: 1 ether}(1);
    }

    /*
    End Auction Test
    */
    function testEndAuctionAsOwner() public {
        initAuction();
        vm.warp(2 * 60 * 60 * 24 + 1);
        dan.endAuction();
        assert(dan.auctionEnded());
    }

    function testEndAuctionAsNonOwner() public {
        initAuction();
        vm.warp(2 * 60 * 60 * 24 + 1);
        startHoax(alice);
        dan.endAuction();
        assert(dan.auctionEnded());
    }

    function testEndAuctionAfterMintOut() public {
        initAuction();
        for (uint256 i = 0; i < 500; i++) {
            dan.mint{value: 1 ether}(1);
        }
        assertEq(dan.balanceOf(address(this)), 500);
        dan.endAuction();
        assert(dan.auctionEnded());
    }

    function testCannotEndAuctionPrematurely() public {
        initAuction();
        vm.warp(1 * 60 * 60 * 24 + 1);
        startHoax(alice);
        vm.expectRevert(DutchAuctionNft.AuctionNotEnded.selector);
        dan.endAuction();
    }

    function testCannotEndAuctionBeforeInit() public {
        startHoax(alice);
        vm.expectRevert(DutchAuctionNft.AuctionNotEnded.selector);
        dan.endAuction();
    }


    /*
    Refund Test
    */
    function testRefundMintOne() public {
        initAuction();
        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 1 ether}(1);
        // jump further than 2 days
        vm.warp(2 * 60 * 60 * 24 + 1);
        dan.endAuction();
        console.log(dan.finalPrice());
        uint256 currentBalance = alice.balance;
        console.log(address(dan).balance);
        dan.refund();
        assertEq(alice.balance, currentBalance + 0.9 ether);
    }

    function testRefundMintThree() public {
        initAuction();

        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 3 ether}(3);

        // jump further than 2 days
        vm.warp(2 * 60 * 60 * 24 + 1);
        dan.endAuction();

        uint256 currentBalance = alice.balance;
        dan.refund();
        assertEq(alice.balance, currentBalance + 2.7 ether);
    }

    function testRefundMintOneHigherPrice() public {
        initAuction();

        startHoax(alice);
        vm.warp(10 * 60 + 1);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 0.95 ether);
        dan.mint{value: 1 ether}(1);

        vm.warp(2 * 60 * 60 * 24 + 1);
        dan.endAuction();

        uint256 currentBalance = alice.balance;
        dan.refund();
        assertEq(alice.balance, currentBalance + 0.85 ether);
    }

    function testRefundAfterSellout() public {
        initAuction();

        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 1 ether}(1);
        assertEq(dan.balanceOf(alice), 1);
        vm.stopPrank();
        vm.warp(10 * 60 + 1);
        for (uint256 i = 0; i < 499; i++) {
            
            dan.mint{value: 0.95 ether}(1);
        }
        assertEq(dan.balanceOf(address(this)), 499);
        dan.endAuction();
        assertEq(dan.finalPrice(), 0.95 ether);
        startHoax(alice);
        uint256 aliceBalance = alice.balance;
        dan.refund();
        
        assertEq(alice.balance, aliceBalance + 0.05 ether);
    }

    function testRefundMintThreeHigherPrice() public {
        initAuction();

        startHoax(alice);
        vm.warp(10 * 60 + 1);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 0.95 ether);
        dan.mint{value: 3 ether}(3);

        vm.warp(2 * 60 * 60 * 24 + 1);
        dan.endAuction();

        uint256 currentBalance = alice.balance;
        dan.refund();
        assertEq(alice.balance, currentBalance + 2.55 ether);
    }

    function testCannotRefundNoMint() public {
        initAuction();

        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 3 ether}(3);

        // jump further than 2 days
        vm.warp(2 * 60 * 60 * 24 + 1);
        dan.endAuction();
        startHoax(alice);
        vm.expectRevert(DutchAuctionNft.NothingToRefund.selector);
        dan.refund();
    }

    function testCannotRefundMintFinalPrice() public {
        initAuction();
        vm.warp(1 * 60 * 60 * 24);
        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 0.1 ether);
        dan.mint{value: 0.3 ether}(3);

        // jump an extra days
        vm.warp(2 * 60 * 60 * 24 + 1);
        dan.endAuction();
        vm.expectRevert(DutchAuctionNft.NothingToRefund.selector);
        dan.refund();
    }

    /*
    Withdraw Test
    */
    function testWithdrawBeforeRefunds() public {
        initAuction();
        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 3 ether}(3);
        assertEq(dan.balanceOf(alice), 3);
        assertEq(address(dan).balance, 3 ether);

        vm.warp(2 * 60 * 60 * 24 + 1);
        dan.endAuction();
        vm.stopPrank();
        uint256 balanceThis = address(this).balance;
        dan.withdraw(address(this));
        assertEq(address(this).balance, balanceThis + 0.3 ether);
    }

    function testWithdrawAfterRefunds() public {
        initAuction();
        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 3 ether}(3);
        assertEq(dan.balanceOf(alice), 3);
        assertEq(address(dan).balance, 3 ether);

        vm.warp(2 * 60 * 60 * 24 + 1);
        uint256 currentBalance = alice.balance;
        dan.endAuction();
        dan.refund();
        assertEq(alice.balance, currentBalance + 2.7 ether);
        vm.stopPrank();

        uint256 balanceThis = address(this).balance;
        dan.withdraw(address(this));
        assertEq(address(this).balance, balanceThis + 0.3 ether);
    }

    function testCannotWithdrawBeforeAuctionEnd() public {
        initAuction();
        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 3 ether}(3);
        assertEq(dan.balanceOf(alice), 3);
        assertEq(address(dan).balance, 3 ether);
        vm.stopPrank();

        vm.expectRevert(DutchAuctionNft.AuctionNotEnded.selector);
        dan.withdraw(address(this));
    }

    function testCannotWithdrawBeforeAuctionEndAfterTimePassed() public {
        initAuction();
        startHoax(alice);
        uint256 currentPrice = dan.calculatePrice();
        assertEq(currentPrice, 1 ether);
        dan.mint{value: 3 ether}(3);
        assertEq(dan.balanceOf(alice), 3);
        assertEq(address(dan).balance, 3 ether);
        vm.stopPrank();

        vm.warp(2 * 60 * 60 * 24 + 1);
        vm.expectRevert(DutchAuctionNft.AuctionNotEnded.selector);
        dan.withdraw(address(this));
    }

    /*
    Helpers
    */
    function initAuction() public {
        dan.initAuction("https://www.test.org/");
    }
    
    receive() external payable {}
}
