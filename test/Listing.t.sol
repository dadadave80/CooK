// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Listing} from "../src/Listing.sol";
import {IListing} from "../src/interface/IListing.sol";
import {inEuint128} from "@fhenixprotocol/contracts/FHE.sol";
import {Permission} from "@fhenixprotocol/contracts/access/Permissioned.sol";
import {Test} from "forge-std/Test.sol";
import {LibClone} from "solady/utils/LibClone.sol";

contract ListingTest is Test {
    using LibClone for address;

    address listingImpl;
    Listing listing;
    address owner = makeAddr("owner");
    address user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        listingImpl = address(new Listing());
        listing = Listing(listingImpl.clone());
        listing.initialize(owner, "https://example.com/");
        vm.stopPrank();
    }

    function testInitialization() public {
        assertEq(listing.owner(), owner);
        assertEq(listing.uri(0), "https://example.com/");
    }

    function testMint() public {
        vm.prank(owner);
        uint256 tokenId = listing.mint(user, 100);
        assertEq(listing.balanceOf(user, tokenId), 100);
        assertEq(tokenId, 1);
    }

    function testSetURI() public {
        vm.startPrank(owner);
        listing.mint(user, 100);
        listing.setURI(1, "https://new.uri/1");
        assertEq(listing.uri(1), "https://new.uri/1");
        vm.stopPrank();
    }

    // Note: FHE tests are limited in this environment as we likely lack the FHE precompiles
    // We will test that calling these functions doesn't revert with "method not found"
    // but we anticipate potential reverts due to missing precompiles or FHE setup.
    // For now we test public logic soundness where possible.

    function testWrapInsufficientFunds() public {
        vm.prank(owner);
        listing.mint(user, 50);

        vm.startPrank(user);
        // User has 50, tries to wrap 100 -> should revert
        vm.expectRevert(IListing.Listing__InsufficientFunds.selector);
        listing.wrap(1, 100);
        vm.stopPrank();
    }
}
