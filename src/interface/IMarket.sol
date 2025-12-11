// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev Struct for listing information
struct ListingInfo {
    // The address of the listing
    address listing;
    // The owner of the listing
    address owner;
    // The price of the listing in USD
    uint128 price;
}

interface IMarket {
    /// @dev Error thrown when the listing creation fails
    error Market__CreateListingFailed();
    /// @dev Error thrown when the listing call fails
    error Market__CallListingFailed(bytes);
    /// @dev Error thrown when the purchase fails
    error Market__PurchaseFailed();
    /// @dev Error thrown when the purchase is not from the pool manager
    error Market__PurchaseNotFromPoolManager();

    /// @dev Emitted when a listing is created
    event ListingCreated(address indexed listing, address indexed owner, uint64 indexed listingId, uint128 price);
    /// @dev Emitted when a listing is called
    event ListingCalled(uint64 indexed listingId, bytes data);
    /// @dev Emitted when a listing price is updated
    event ListingPriceUpdated(uint64 indexed listingId, uint128 price);

    /// @notice Creates a new listing
    /// @param price The price of the listing in USD
    /// @param uri The URI of the NFT collection
    /// @param salt The salt to use for the deterministic clone
    /// @return The address of the new listing
    function createListing(uint128 price, string calldata uri, bytes32 salt) external returns (address);

    /// @notice Sends arbitrary calls to a listing
    /// @param listingId The ID of the listing to call
    /// @param data The data to call the listing with
    function callListing(uint64 listingId, bytes calldata data) external returns (bytes memory);

    /// @notice Updates the price of a listing
    /// @param listingId The ID of the listing to update
    /// @param price The new price of the listing
    function updateListingPrice(uint64 listingId, uint128 price) external;

    /// @notice Purchases a listing
    /// @param listingId The ID of the listing to purchase
    /// @param quantity The amount of tokens to purchase
    /// @param recipient The recipient of the tokens
    function purchase(uint64 listingId, uint96 quantity, address recipient) external;

    /// @notice Gets a listing
    /// @param listingId The ID of the listing to get
    /// @return The listing
    function getListingInfoExt(uint64 listingId) external view returns (ListingInfo memory);

    /// @notice Gets a listing by owner
    /// @param owner The owner of the listing
    /// @return The list of listings
    function getListingInfoByOwner(address owner) external view returns (ListingInfo[] memory);

    /// @notice Gets all listings
    /// @return The list of listings
    function getAllListingInfo() external view returns (ListingInfo[] memory);

    /// @notice Gets the number of listings
    function listingCount() external view returns (uint64);

    /// @notice Gets the USDC address
    function USDC() external view returns (address);
}
