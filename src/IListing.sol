// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface IListing is IERC721Metadata, IERC721Enumerable {
    /// @dev Error thrown when the name is empty
    error Listing__NameEmpty();

    /// @dev Error thrown when the token is frozen
    error Listing__TokenFrozen(uint256 tokenId);

    /// @notice Emitted when the base URI is updated
    /// @param newBaseUri The new base URI set for the NFT collection
    event BaseURIUpdated(string indexed newBaseUri);

    /// @notice Emitted when the metadata of the NFT collection is updated
    /// @param newName The new name of the NFT collection
    event NameUpdated(string indexed newName);

    /// @notice Emitted when the metadata of the NFT collection is updated
    /// @param newSymbol The new symbol of the NFT collection
    event SymbolUpdated(string indexed newSymbol);

    /// @notice Emitted when a token is frozen
    /// @param tokenId The ID of the token
    /// @param status The new status of the token
    event Frozen(uint256 indexed tokenId, bool status);

    /// @notice Initializes the contract
    /// @param owner The owner of the contract
    /// @param royaltyReceiver The royalty receiver of the NFT collection
    /// @param name The name of the NFT collection
    /// @param symbol The symbol of the NFT collection
    /// @param uri The URI of the NFT collection
    function initialize(
        address owner,
        address royaltyReceiver,
        string calldata name,
        string calldata symbol,
        string calldata uri
    ) external;

    /// @notice Mints a new token to a given address
    /// @param to The address to receive the newly minted token
    function mint(address to) external;

    /// @notice Mints a consecutive range of tokens to a given address
    /// @param to The address to receive the newly minted tokens
    /// @param amount The number of tokens to mint
    /// @return The ID of the first token minted in the batch
    function mintConsecutive(address to, uint96 amount) external returns (uint96);

    /// @notice Updates the name of the NFT collection
    /// @param name The name to assign
    function updateName(string calldata name) external;

    /// @notice Updates the symbol of the NFT collection
    /// @param symbol The symbol to assign
    function updateSymbol(string calldata symbol) external;

    /// @notice Updates the base URI of the NFT collection
    /// forge-lint: disable-next-line(mixed-case-function)
    function updateURI(string calldata uri) external;

    /// @notice Allows the owner to update the default royalty
    /// @param receiver The address to receive the royalty
    /// @param feeNumerator The numerator of the royalty fee
    function updateDefaultRoyalty(address receiver, uint96 feeNumerator) external;

    /// @notice Allows the owner to update the token royalty
    /// @param tokenId The ID of the token to update the royalty for
    /// @param receiver The address to receive the royalty
    /// @param feeNumerator The numerator of the royalty fee
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external;

    /// @notice Allows the owner to reset the token royalty
    /// @param tokenId The ID of the token to reset the royalty for
    function resetTokenRoyalty(uint256 tokenId) external;

    /// @notice Pauses token transfers
    function pause() external;

    /// @notice Unpauses token transfers
    function unpause() external;

    /// @notice Checks if token transfers are paused
    function paused() external view returns (bool);

    /// @notice Freezes a token
    /// @param _tokenId The ID of the token to freeze
    function freeze(uint256 _tokenId) external;

    /// @notice Unfreezes a token
    /// @param _tokenId The ID of the token to unfreeze
    function unfreeze(uint256 _tokenId) external;

    /// @notice Returns the base URI of the NFT collection
    /// forge-lint: disable-next-line(mixed-case-function)
    function baseURI() external view returns (string memory);

    /// @notice Returns the metadata URI for the TicketNFT
    /// @dev This function returns the base URI set for the NFT collection, which is used
    /// @param tokenId The ID of the token
    /// @return The URI pointing to the token's metadata
    /// forge-lint: disable-next-line(mixed-case-function)
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
