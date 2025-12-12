// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// External: OpenZeppelin
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ERC1155Upgradeable,
    IERC1155MetadataURI,
    IERC165
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {
    ERC1155PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import {
    ERC1155SupplyUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {
    ERC1155URIStorageUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";

// External: Fhenix
import {FHE, euint256, inEuint256} from "@fhenixprotocol/contracts/FHE.sol";
import {Permission, Permissioned} from "@fhenixprotocol/contracts/access/Permissioned.sol";

// Internal
import {IListing} from "./interface/IListing.sol";

/*
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣠⣤⣀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⡾⠟⠋⠉⠉⠙⣷
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣶⠟⠋⠁⠀⠀⠀⠀⠀⠀⣿⠇
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠀⠀⠀⣠⣴⠟⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡿
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡾⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⠟⠁
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡾⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⠟⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⠤⠤⠤⡄⢤⠠⡄⢤⠠⡄⢤⡀⣄⢠⣀⣀⣀⢀⡴⢟⢀⡀⣀⢀⠀⠀⠀⠀⠀⣀⣴⠾⠋⠁
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣌⢣⠝⣪⢑⠎⡥⡓⣜⢢⠓⣜⠢⠵⣈⠶⡐⢦⡘⢆⢎⡱⢊⡴⢡⠎⡅⢀⣠⣴⠿⠋⠁
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣌⠳⣌⠲⣉⠦⡍⢎⡱⠱⣌⠲⡍⢆⡫⣑⢎⠲⣉⢦⡙⢬⢊⡴⢋⢴⣣⣽⡾⠟⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣌⠳⣌⠳⣌⢣⢱⢊⠼⡱⣘⢣⡌⠳⣌⠳⣐⠣⢎⡱⢃⢦⡙⢆⣣⣼⡿⢟⢏⠳⡄
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣌⠳⣌⠳⣌⠳⣌⠲⣡⢎⠣⣕⡘⠦⡜⠳⣌⠣⠅⠋⠀⣵⡏⠦⣹⣾⡟⡫⢜⡡⢎⠳⡐
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣐⢎⡱⢢⡙⢦⣉⠳⡌⠁⠀⠀⢸⡿⣡⣾⠟⣱⡘⡱⢊⡼⢌⢣⢣
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡌⢆⢇⢣⠞⡤⢃⡳⠄⠀⠀⠀⠘⠿⠋⠁⠀⢦⠱⣉⠧⣘⠬⣃⠖
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡌⡍⢎⠦⡙⡔⢫⠔⣣⠀⠀⠀⠀⠀⠀⠀⡐⢎⡱⢥⠚⡥⢚⢤⢋
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡌⠵⣊⠵⡩⢜⡡⠞⡤⢓⡤⣀⣀⠠⡄⢎⡱⢎⠲⣡⢋⡴⢋⠦⣩
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡌⢖⣩⠒⣍⡚⠴⣉⠖⣡⢎⡱⢊⡵⡘⣌⠳⣐⢣⠜⣡⠞⣡
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣘⠬⢢⠝⡤⠹⣌⡱⢊⡕⢪⠔⡫⢔⡱⢊⠵⡡⠞⡬⡑⢎⠲
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠣⣍⢚⡌⢳⠤⣃⠏⡜⣡⠞⡱⢊⡴⢋⠖⣩⠚⡴⣉⠮⣑⠂
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡌⢦⡙⢆⡳⢌⢎⡱⢆⣙⠲⣉⠖⡩⢎⠥⣋⠴⡑⣎⠱⠂
⠀⠀⠀⠀⠀⠀⠀⠠⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡘⢦⡙⢦⡑⢮⡘⠴⣉⠦⣙⢤⢋⡕⢪⡑⢎⡱⠱⠬⠉
⠀⠀⠀⠀⠀⠠⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⢣⡙⢦⡙⢦⡙⢦⡙⢬⣑⠚⣌⠦⣃⠮⣑⢎⡱⠊⠉
⠀⠀⠀⠠⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡌⢦⡙⢦⡙⢦⡙⢦⡙⠦⣌⠫⡔⢣⠜⡲⢡⠎⠂
⠀⠠⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡘⢦⡙⢦⡙⢦⡙⢦⡙⠲⣌⠳⡘⡥⢋⡴⠋
⢌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⢣⡙⢦⡙⢦⡙⢦⡙⢦⣉⠳⣌⠣⠵⡡⠃
⠀⠁⢪⠱⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡌⢦⡙⢦⡙⢦⡙⢦⡙⠦⣌⠳⣌⠣⠉⠀
⠀⠀⠀⠑⠌⡳⢌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡘⢦⡙⢦⡙⢦⡙⢦⡙⠲⣌⠳⠈
⠀⠀⠀⠀⠀⠑⢪⠱⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⢣⡙⢦⡙⢦⡙⢦⡙⢦⣉⠳⠈
⠀⠀⠀⠀⠀⠀⠀⠑⠌⡳⢌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡌⢦⡙⢦⡙⢦⡙⢦⡙⠦⠈
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⢪⠱⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡘⢦⡙⢦⡙⢦⡙⠦⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⠌⡳⢌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⢣⡙⢦⡙⢦⡙⠦⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⢪⠱⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡌⢦⡙⢦⡙⠦⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⢌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⠳⡘⢦⡙⠦⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⢌⠳⣌⠳⣌⠳⣌⠳⣌⠳⣌⢣⡙⠦⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⢌⠳⣌⠳⣌⠳⣌⠳⣌⠲⠉
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⢌⠳⣌⠳⣌⠳⠈
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⢌⠳⠈
*/

/// @title Listing
/// @author David Dada (https://github.com/dadadave80)
/// @notice The listing contract is the entry point for all listing operations
contract Listing is
    ERC1155SupplyUpgradeable,
    ERC1155URIStorageUpgradeable,
    ERC1155PausableUpgradeable,
    OwnableUpgradeable,
    IListing
{
    //*//////////////////////////////////////////////////////////////////////////
    //                         CONSTRUCTOR & INITIALIZER
    //////////////////////////////////////////////////////////////////////////*//

    /// @notice Constructor disables initializer on the implementation contract
    /// @dev Only proxy contracts can initialize
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _owner The owner of the contract
    /// @param _uri The URI of the NFT collection
    function initialize(address _owner, string calldata _uri) public initializer {
        __Ownable_init(_owner);
        __ERC1155_init(_uri);
        __ERC1155URIStorage_init();
    }

    //*//////////////////////////////////////////////////////////////////////////
    //                             EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*//

    /// @notice Mints a consecutive range of tokens to a given address
    /// @param _to The address to receive the newly minted tokens
    /// @param _quantity The number of tokens to mint
    /// @return tokenId_ The ID of the first token minted in the batch
    function mint(address _to, uint96 _quantity) external onlyOwner returns (uint256 tokenId_) {
        tokenId_ = totalSupply() + 1;
        _mint(_to, tokenId_, _quantity, "");
    }

    /// @notice Sets the URI for a specific token
    /// @param _tokenId The ID of the token
    /// @param _uri The URI to set
    function setURI(uint256 _tokenId, string memory _uri) external onlyOwner {
        _setURI(_tokenId, _uri);
    }

    /// @notice Sets the base URI for the collection
    /// @param _baseURI The base URI to set
    function setBaseURI(string memory _baseURI) external onlyOwner {
        _setBaseURI(_baseURI);
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

    //*//////////////////////////////////////////////////////////////////////////
    //                                 OVERRIDES
    //////////////////////////////////////////////////////////////////////////*//

    /// @notice Updates the balance of a given address for a given token
    /// @param _from The address to transfer from
    /// @param _to The address to transfer to
    /// @param _ids The IDs of the tokens to transfer
    /// @param _values The values of the tokens to transfer
    function _update(address _from, address _to, uint256[] memory _ids, uint256[] memory _values)
        internal
        virtual
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable, ERC1155PausableUpgradeable)
    {
        super._update(_from, _to, _ids, _values);
    }

    //*//////////////////////////////////////////////////////////////////////////
    //                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*//

    /// @notice Returns the URI for a specific token
    /// @param _tokenId The ID of the token
    /// @return The URI of the token
    function uri(uint256 _tokenId)
        public
        view
        virtual
        override(IERC1155MetadataURI, ERC1155Upgradeable, ERC1155URIStorageUpgradeable)
        returns (string memory)
    {
        return super.uri(_tokenId);
    }

    /// @notice Returns whether a given interface is supported by the contract
    /// @param _interfaceId The interface ID to check
    /// @return Whether the interface is supported
    function supportsInterface(bytes4 _interfaceId) public view override(IERC165, ERC1155Upgradeable) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }
}
