// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Listing} from "../src/Listing.sol";
import {Market} from "../src/Market.sol";
import {IListing} from "../src/interface/IListing.sol";
import {IMarket, ListingInfo} from "../src/interface/IMarket.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

contract MarketTest is Test {
    Market market;
    MockERC20 usdc;
    address owner = makeAddr("owner");
    address recipient = makeAddr("recipient");

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        market = new Market(address(usdc));
    }

    function testCreateListing() public {
        uint128 price = 100 * 1e6;
        string memory uri = "https://example.com";

        vm.prank(owner);
        address listingAddr = market.createListing(price, uri, bytes32(0));

        assertTrue(listingAddr != address(0));

        ListingInfo memory info = market.getListingInfoExt(1);

        assertEq(info.listing, listingAddr);
        assertEq(info.owner, owner);
        assertEq(info.price, price);

        // Check listing initialization
        assertEq(IListing(listingAddr).uri(0), uri);
    }

    function testUpdateListingPrice() public {
        uint128 price = 100 * 1e6;
        vm.prank(owner);
        market.createListing(price, "uri", bytes32(0));

        uint128 newPrice = 200 * 1e6;
        vm.prank(owner);
        market.updateListingPrice(1, newPrice);

        ListingInfo memory info = market.getListingInfoExt(1);
        assertEq(info.price, newPrice);
    }

    function testUpdateListingPriceUnauthorized() public {
        uint128 price = 100 * 1e6;
        vm.prank(owner);
        market.createListing(price, "uri", bytes32(0));

        vm.prank(recipient);
        vm.expectRevert(); // Should revert with AccessControl error
        market.updateListingPrice(1, 200 * 1e6);
    }

    function testPurchase() public {
        uint128 price = 10 * 1e6;
        vm.prank(owner);
        address listingAddr = market.createListing(price, "uri", bytes32(0));

        // Fund recipient
        usdc.mint(recipient, 100 * 1e6);

        vm.startPrank(recipient);
        usdc.approve(address(market), 100 * 1e6);

        // Purchase 2 items
        market.purchase(1, 2, recipient);
        vm.stopPrank();

        // Check balances
        assertEq(IListing(listingAddr).balanceOf(recipient, 1), 2);
        assertEq(usdc.balanceOf(owner), 20 * 1e6);
        assertEq(usdc.balanceOf(recipient), 80 * 1e6);
    }

    function testPurchaseInvalidQuantity() public {
        uint128 price = 10 * 1e6;
        vm.prank(owner);
        market.createListing(price, "uri", bytes32(0));

        vm.prank(recipient);
        vm.expectRevert(IMarket.Market__InvalidQuantity.selector);
        market.purchase(1, 0, recipient);
    }
}
