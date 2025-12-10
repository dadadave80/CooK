// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721ConsecutiveUpgradeable} from "./ERC721ConsecutiveUpgradeable.sol";
import {
    ERC721EnumerableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {
    ERC721RoyaltyUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IListing} from "./IListing.sol";

contract Listing is
    ERC721EnumerableUpgradeable,
    ERC721ConsecutiveUpgradeable,
    ERC721RoyaltyUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    IListing
{
    //*//////////////////////////////////////////////////////////////////////////
    //                                  STORAGE
    //////////////////////////////////////////////////////////////////////////*//

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC721")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC721_LOCATION = 0x80bb2b638cc20bc4d0a60d66940f3ab4a00c1d7b313497ca82fb0b4ab0079300;

    // keccak256(abi.encode(uint256(keccak256("listing.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LISTING_LOCATION = 0x80bb2b638cc20bc4d0a60d66940f3ab4a00c1d7b313497ca82fb0b4ab0079300;

    /// @dev Internal function to retrieve the storage location of the ERC721Storage struct
    function _getErc721Storage() private pure returns (ERC721Storage storage $) {
        assembly {
            $.slot := ERC721_LOCATION
        }
    }

    /// @dev Internal function to retrieve the storage location of the ListingStorage struct
    function _getListingStorage() private pure returns (ListingStorage storage $) {
        assembly {
            $.slot := LISTING_LOCATION
        }
    }

    /// @custom:storage-location erc7201:listing.storage
    struct ListingStorage {
        string listingUri;
        mapping(uint256 => bool) isFrozen;
    }

    modifier whenNotFrozen(uint256 _tokenId) {
        if (frozen(_tokenId)) revert Listing__TokenFrozen(_tokenId);
        _;
    }

    //*//////////////////////////////////////////////////////////////////////////
    //                         CONSTRUCTOR & INITIALIZER
    //////////////////////////////////////////////////////////////////////////*//

    /// @notice Constructor disables initializers on implementation contracts
    /// @dev Only proxy contracts can initialize this contract
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _owner The owner of the contract
    /// @param _royaltyReceiver The royalty receiver of the NFT collection
    /// @param _name The name of the NFT collection
    /// @param _symbol The symbol of the NFT collection
    /// @param _uri The URI of the NFT collection
    function initialize(
        address _owner,
        address _royaltyReceiver,
        string calldata _name,
        string calldata _symbol,
        string calldata _uri
    ) public initializer {
        // Revert if name is empty
        if (bytes(_name).length == 0) revert Listing__NameEmpty();

        // Default symbol to LISTING if symbol is empty
        string memory symbol = bytes(_symbol).length == 0 ? "LISTING" : _symbol;
        __ERC721_init(_name, symbol);
        __ERC721Enumerable_init();
        __ERC721Royalty_init();
        __Ownable_init(_owner);

        // Set default royalty to 5%
        _setDefaultRoyalty(_royaltyReceiver, 500);

        _getListingStorage().listingUri = _uri;
    }

    //*//////////////////////////////////////////////////////////////////////////
    //                             EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*//

    /// @notice Mints a new token to a given address
    /// @param _to The address to receive the newly minted token
    function mint(address _to) external onlyOwner {
        _safeMint(_to, _nextConsecutiveId());
    }

    /// @notice Mints a consecutive range of tokens to a given address
    /// @param _to The address to receive the newly minted tokens
    /// @param _amount The number of tokens to mint
    /// @return The ID of the first token minted in the batch
    function mintConsecutive(address _to, uint96 _amount) external onlyOwner returns (uint96) {
        return _mintConsecutive(_to, _amount);
    }

    /// @notice Allows the owner to update the name of the NFT collection
    /// @param _name The name to assign
    function updateName(string calldata _name) external onlyOwner {
        _getErc721Storage()._name = _name;
        emit NameUpdated(_name);
    }

    /// @notice Allows the owner to update the symbol of the NFT collection
    /// @param _symbol The symbol to assign
    function updateSymbol(string calldata _symbol) external onlyOwner {
        _getErc721Storage()._symbol = _symbol;
        emit SymbolUpdated(_symbol);
    }

    /// @notice Allows the owner to set the base URI
    /// @param __baseUri The URI to assign
    /// forge-lint: disable-next-line(mixed-case-function)
    function updateURI(string calldata __baseUri) external onlyOwner {
        _getListingStorage().listingUri = __baseUri;
        emit BaseURIUpdated(__baseUri);
    }

    /// @notice Allows the owner to update the default royalty
    /// @param _receiver The address to receive the royalty
    /// @param _feeNumerator The numerator of the royalty fee
    function updateDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyOwner {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /// @notice Allows the owner to update the token royalty
    /// @param _tokenId The ID of the token to update the royalty for
    /// @param _receiver The address to receive the royalty
    /// @param _feeNumerator The numerator of the royalty fee
    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator) external onlyOwner {
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }

    /// @notice Allows the owner to reset the token royalty
    /// @param _tokenId The ID of the token to reset the royalty for
    function resetTokenRoyalty(uint256 _tokenId) external onlyOwner {
        _resetTokenRoyalty(_tokenId);
    }

    /// @notice Pauses token transfers
    /// @dev This function is used to pause token transfers
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses token transfers
    /// @dev This function is used to unpause token transfers
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Freezes a token
    /// @param _tokenId The ID of the token to freeze
    function freeze(uint256 _tokenId) external onlyOwner {
        _getListingStorage().isFrozen[_tokenId] = true;
        emit Frozen(_tokenId, true);
    }

    /// @notice Unfreezes a token
    /// @param _tokenId The ID of the token to unfreeze
    function unfreeze(uint256 _tokenId) external onlyOwner {
        _getListingStorage().isFrozen[_tokenId] = false;
        emit Frozen(_tokenId, false);
    }

    //*//////////////////////////////////////////////////////////////////////////
    //                                 OVERRIDES
    //////////////////////////////////////////////////////////////////////////*//

    /// @dev Internal override for base URI, returns the set base URI
    /// @notice This function is used to retrieve the base URI for the NFT collection
    /// @return The base URI for the NFT collection
    /// forge-lint: disable-next-line(mixed-case-function)
    function _baseURI() internal view override returns (string memory) {
        return _getListingStorage().listingUri;
    }

    /// @dev Internal override for token transfer logic
    /// @param _to The address to transfer the token to
    /// @param _tokenId The ID of the token to transfer
    /// @param _auth The address authorized to transfer the token
    /// @return The address of the token owner
    function _update(address _to, uint256 _tokenId, address _auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721ConsecutiveUpgradeable)
        whenNotPaused
        whenNotFrozen(_tokenId)
        returns (address)
    {
        return super._update(_to, _tokenId, _auth);
    }

    /// @dev Internal override for increasing balance
    /// @param account The address to increase the balance for
    /// @param amount The amount to increase the balance by
    function _increaseBalance(address account, uint128 amount)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, amount);
    }

    /// @dev Internal override for ownerOf
    /// @param _tokenId The ID of the token
    /// @return The address of the token owner
    function _ownerOf(uint256 _tokenId)
        internal
        view
        override(ERC721Upgradeable, ERC721ConsecutiveUpgradeable)
        returns (address)
    {
        return super.ownerOf(_tokenId);
    }

    //*//////////////////////////////////////////////////////////////////////////
    //                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*//

    /// @notice Returns whether the contract is paused
    /// @return Whether the contract is paused
    function paused() public view override(IListing, PausableUpgradeable) returns (bool) {
        return super.paused();
    }

    /// @notice Returns whether a token is frozen
    /// @param _tokenId The ID of the token
    /// @return Whether the token is frozen
    function frozen(uint256 _tokenId) public view returns (bool) {
        return _getListingStorage().isFrozen[_tokenId];
    }

    /// @notice Returns the metadata URI for the TicketNFT
    /// @dev This function returns the base URI set for the NFT collection, which is used
    /// @return The URI pointing to the token's metadata
    /// forge-lint: disable-next-line(mixed-case-function)
    function tokenURI(
        uint256 /*_tokenId*/
    )
        public
        view
        override(ERC721Upgradeable, IListing)
        returns (string memory)
    {
        return _baseURI();
    }

    /// @notice Returns the metadata URI for the TicketNFT
    /// @dev This function returns the base URI set for the NFT collection, which is used
    /// @return The URI pointing to the collection's metadata
    /// forge-lint: disable-next-line(mixed-case-function)
    function baseURI() public view returns (string memory) {
        return _baseURI();
    }

    /// @notice Returns whether a given interface is supported by the contract
    /// @param _interfaceId The interface ID to check
    /// @return Whether the interface is supported
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(IERC165, ERC721Upgradeable, ERC721RoyaltyUpgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(_interfaceId);
    }
}
