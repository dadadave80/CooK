// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";

interface IListing is IERC1155, IERC1155MetadataURI {
    /// @dev Error thrown when the token is frozen
    error Listing__TokenFrozen(uint256 tokenId);

    /// @notice Emitted when a token is frozen
    /// @param tokenId The ID of the token
    /// @param status The new status of the token
    event Frozen(uint256 indexed tokenId, bool status);

    /// @notice Initializes the contract
    /// @param owner The owner of the contract
    /// @param uri The URI of the NFT collection
    function initialize(address owner, string calldata uri) external;

    /// @notice Mints a consecutive range of tokens to a given address
    /// @param to The address to receive the newly minted tokens
    /// @param amount The number of tokens to mint
    /// @return The ID of the first token minted in the batch
    function mint(address to, uint96 amount) external returns (uint256);

    /// @notice Sets the URI for a specific token
    /// @param tokenId The ID of the token
    /// @param uri The URI to set
    function setURI(uint256 tokenId, string memory uri) external;

    /// @notice Sets the base URI for the collection
    /// @param baseURI The base URI to set
    function setBaseURI(string memory baseURI) external;

    /// @notice Pauses token transfers
    function pause() external;

    /// @notice Unpauses token transfers
    function unpause() external;
}
