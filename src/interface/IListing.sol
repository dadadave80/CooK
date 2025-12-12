// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

import {inEuint128} from "@fhenixprotocol/contracts/FHE.sol";
import {Permission} from "@fhenixprotocol/contracts/access/Permissioned.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";

interface IListing is IERC1155, IERC1155MetadataURI {
    /// @dev Error thrown when the user does not have enough funds
    error Listing__InsufficientFunds();
    /// @dev Error thrown when the account is not the caller
    error Listing__AccountMustBeCaller();

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

    /// @notice Converts public tokens to private encrypted tokens
    /// @param id The ID of the token to wrap
    /// @param amount The amount of tokens to wrap
    function wrap(uint256 id, uint256 amount) external;

    /// @notice Converts private encrypted tokens to public tokens
    /// @param id The ID of the token to unwrap
    /// @param amount The encrypted amount of tokens to unwrap
    function unwrap(uint256 id, inEuint128 memory amount) external;

    /// @notice Transfers encrypted tokens to another address
    /// @param to The address to transfer to
    /// @param id The ID of the token to transfer
    /// @param amount The encrypted amount to transfer
    function transferEncrypted(address to, uint256 id, inEuint128 memory amount) external;

    /// @notice Returns the encrypted balance of a user (viewable only by user)
    /// @param account The address of the user
    /// @param id The ID of the token
    /// @param auth The permission signature
    /// @return The decrypted balance
    function balanceOfEncrypted(address account, uint256 id, Permission memory auth) external view returns (uint256);
}
