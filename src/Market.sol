// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// External: OpenZeppelin
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
// External: Solady
import {LibClone} from "solady/utils/LibClone.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
// External: Uniswap / Hookmate
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IUniswapV4Router04} from "hookmate/interfaces/router/IUniswapV4Router04.sol";
import {PathKey} from "hookmate/interfaces/router/PathKey.sol";
// Internal
import {IListing, Listing} from "./Listing.sol";
import {IMarket, ListingInfo, PurchaseData, RouterData} from "./interface/IMarket.sol";

/*
                  Hey fren!
                  Let me buy some potatoes

                               _......._
           *****            .-:::::::::::-.
          /     \         .:::::::::::::::::.
 (^^^|    **********     ::::::::::::::::::::::
  \(\/    | -  - |      :: _   _  ___  ___  ::::
   \ \   .  O  O  .    :::| | | || __|| __ \:::::
    \ \   |   ~  |     :::| | | || |_ | | | |::::
    \  \   \ == /      :::| | | ||_  || | | |::::
     \  \___|  |___    :::| |_| | _| || |_| |::::           __________________
      \ /   \__/   \    ::|_____||___||____/:::::       .-'"___________________`-.|+
       \            \    :::::::::::::::::::::::       ( .'"                   '-.)+
        --|      |\_/\  / `::::::::::::::::::'         |`-..__________________..-'|+
          |      | \  \/ /  `-::::::::::::-'           |                          |+
          |      |  \   /      `''''''''`              |                          |+
          |      |   \_/                               |       ---     ---        |+
          |______|                                     |       (  )    (  )       |+
          |__X___|             ┌──────────────┐      /`|                          |+
          |      |             │$            $│     / /|            [             |+
          |  |   |             │   G O O D S  │    / / |        ----------        |+
          |  |  _|             │              │\.-" ;  \        \________/        /+
          |  |  |              │$            $│),.-'    `-..__________________..-' +=
          |  |  |              └──────────────┘                |    | |    |
          (  (  |                                              |    | |    |
          |  |  |                                              |    | |    |
          |  |  |                                              T----T T----T
         _|  |  |                                         _..._L____J L____J _..._
        (_____[__)                                      .` "-. `%   | |    %` .-" `.
                                                       /      \    .: :.     /      \
                                                       '-..___|_..=:` `-:=.._|___..-'
 */

/// @title Market
/// @author David Dada (https://github.com/dadadave80)
/// @notice The market contract is the entry point for all market operations
contract Market is AccessControl, IMarket {
    using LibClone for address;
    using SafeTransferLib for address;
    using EnumerableSet for EnumerableSet.UintSet;

    //*//////////////////////////////////////////////////////////////////////////
    //                              STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*//

    address public immutable USDC;
    address public immutable LISTING_IMPL;
    uint64 public listingCount;
    mapping(uint64 => ListingInfo) getListingInfo;
    mapping(address => EnumerableSet.UintSet) ownerToListingIds;

    //*//////////////////////////////////////////////////////////////////////////
    //                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*//

    constructor(address _usdc) {
        USDC = _usdc;
        LISTING_IMPL = address(new Listing());
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @notice Creates a new listing
    /// @param _price The price of the listing in USD
    /// @param _uri The URI of the NFT collection
    /// @param _salt The salt to use for the deterministic clone
    /// @return listing_ The address of the new listing
    function createListing(uint128 _price, string calldata _uri, bytes32 _salt) external returns (address listing_) {
        listing_ = _salt.length == 0 ? LISTING_IMPL.clone() : LISTING_IMPL.cloneDeterministic(_salt);

        address caller = msg.sender;
        try IListing(listing_).initialize(address(this), _uri) {
            uint64 listingId = ++listingCount;
            bytes32 listingRole = _getListingRole(caller, listingId);
            getListingInfo[listingId] = ListingInfo({listing: listing_, owner: caller, price: _price});
            ownerToListingIds[caller].add(listingId);
            _grantRole(listingRole, caller);
            emit ListingCreated(listing_, caller, listingId, _price);
        } catch {
            revert Market__CreateListingFailed();
        }
    }

    /// @notice Sends arbitrary calls to a listing
    /// @param _listingId The ID of the listing to call
    /// @param _data The data to call the listing with
    function callListing(uint64 _listingId, bytes calldata _data)
        external
        onlyRole(_getListingRole(msg.sender, _listingId))
        returns (bytes memory)
    {
        (bool success, bytes memory data) = getListingInfo[_listingId].listing.call(_data);
        if (!success) {
            revert Market__CallListingFailed(data);
        }
        emit ListingCalled(_listingId, _data);
        return data;
    }

    /// @notice Updates the price of a listing
    /// @param _listingId The ID of the listing to update
    /// @param _price The new price of the listing
    function updateListingPrice(uint64 _listingId, uint128 _price)
        external
        onlyRole(_getListingRole(msg.sender, _listingId))
    {
        getListingInfo[_listingId].price = _price;
        emit ListingPriceUpdated(_listingId, _price);
    }

    /// @notice Purchases a listing
    /// @param _listingId The ID of the listing to purchase
    /// @param _quantity The amount of tokens to purchase
    /// @param _recipient The recipient of the tokens
    function purchase(uint64 _listingId, uint96 _quantity, address _recipient) external {
        if (_quantity == 0) revert Market__InvalidQuantity();
        ListingInfo memory listingInfo = getListingInfo[_listingId];

        USDC.safeTransferFrom(msg.sender, listingInfo.owner, listingInfo.price * _quantity);

        try IListing(listingInfo.listing).mint(_recipient, _quantity) {
            emit ListingPurchased(_listingId, msg.sender, _quantity);
        } catch {
            revert Market__PurchaseFailed();
        }
    }

    /// @notice Purchases a listing using a token swap via Uniswap V4 Router
    /// @param _purchaseData The purchase data
    /// @param _routerData The router data
    /// @param _token The token to swap from
    function purchaseWithToken(PurchaseData calldata _purchaseData, RouterData calldata _routerData, address _token)
        external
    {
        if (_purchaseData.quantity == 0) revert Market__InvalidQuantity();

        ListingInfo memory listingInfo = getListingInfo[_purchaseData.listingId];
        if (listingInfo.listing == address(0)) revert Market__PurchaseFailed();

        // 1. Pull tokens from user
        _token.safeTransferFrom(msg.sender, address(this), _routerData.amountIn);

        // 2. Approve Router
        _token.safeApprove(_routerData.router, _routerData.amountIn);

        // 3. Route Swap
        _routeSwap(_purchaseData, _routerData, _token);

        // 4. Reset Approval
        _token.safeApprove(_routerData.router, 0);
    }

    function _routeSwap(PurchaseData calldata _purchaseData, RouterData calldata _routerData, address _token) internal {
        bytes memory purchaseHookData = abi.encode(_purchaseData);

        // 1. Construct PathKey[] memory with hookData in the last hop
        uint256 pathLength = _routerData.path.length;
        PathKey[] memory newPath = new PathKey[](pathLength);
        for (uint256 i; i < pathLength; ++i) {
            newPath[i] = _routerData.path[i];
        }
        // Set hookData for the final pool
        newPath[pathLength - 1].hookData = purchaseHookData;

        // 2. Execute Swap (Exact Input)
        IUniswapV4Router04(payable(_routerData.router))
            .swapExactTokensForTokens(
                _routerData.amountIn,
                _routerData.amountOutMin,
                Currency.wrap(_token),
                newPath,
                _purchaseData.recipient,
                _routerData.deadline
            );
    }

    /// @notice Gets a listing
    /// @param _listingId The ID of the listing to get
    /// @return The listing
    function getListingInfoExt(uint64 _listingId) external view returns (ListingInfo memory) {
        return getListingInfo[_listingId];
    }

    /// @notice Gets a listing by owner
    /// @param _owner The owner of the listing
    /// @return listings_ The list of listings
    function getListingInfoByOwner(address _owner) external view returns (ListingInfo[] memory listings_) {
        EnumerableSet.UintSet storage listingIds = ownerToListingIds[_owner];
        listings_ = new ListingInfo[](listingIds.length());
        for (uint64 i; i < listingIds.length(); ++i) {
            listings_[i] = getListingInfo[uint64(listingIds.at(i))];
        }
    }

    /// @notice Gets all listings
    /// @return listings_ The list of listings
    function getAllListingInfo() external view returns (ListingInfo[] memory listings_) {
        listings_ = new ListingInfo[](listingCount);
        for (uint64 i; i < listingCount; ++i) {
            listings_[i] = getListingInfo[i];
        }
    }

    /// @notice Gets the role for a listing
    /// @param _caller The caller of the function
    /// @param _listingId The ID of the listing
    /// @return listingRole_ The role for the listing
    function _getListingRole(address _caller, uint64 _listingId) internal pure returns (bytes32 listingRole_) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, _caller)
            mstore(add(ptr, 0x20), _listingId)
            listingRole_ := keccak256(ptr, 0x40)
        }
    }
}
