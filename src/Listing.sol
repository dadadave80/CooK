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
import {FHE, euint128, inEuint128} from "@fhenixprotocol/contracts/FHE.sol";
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
    Permissioned,
    IListing
{
    //*//////////////////////////////////////////////////////////////////////////
    //                              PRIVATE STORAGE
    //////////////////////////////////////////////////////////////////////////*//

    // keccak256(abi.encode(uint256(keccak256("listing.storage.fhe")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant FHE_STORAGE_LOCATION = 0x7dc9e34006a1986414583b062970439fd65c73dd9e94af3022f6fa80cafe5e00;

    struct FHEStorage {
        mapping(uint256 id => mapping(address account => euint128)) _privateBalances;
    }

    function _getFHEStorage() internal pure returns (FHEStorage storage $) {
        assembly {
            $.slot := FHE_STORAGE_LOCATION
        }
    }

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
    //                             PRIVACY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*//

    /// @notice Converts public tokens to private encrypted tokens
    /// @param _id The ID of the token to wrap
    /// @param _amount The amount of tokens to wrap
    function wrap(uint256 _id, uint256 _amount) external {
        if (balanceOf(msg.sender, _id) < _amount) {
            revert Listing__InsufficientFunds();
        }
        _burn(msg.sender, _id, _amount);
        FHEStorage storage $ = _getFHEStorage();
        euint128 currentBalance = $._privateBalances[_id][msg.sender];
        if (!FHE.isInitialized(currentBalance)) {
            $._privateBalances[_id][msg.sender] = FHE.asEuint128(uint128(_amount));
        } else {
            $._privateBalances[_id][msg.sender] = FHE.add(currentBalance, FHE.asEuint128(uint128(_amount)));
        }
    }

    /// @notice Converts private encrypted tokens to public tokens
    /// @param _id The ID of the token to unwrap
    /// @param _amount The encrypted amount of tokens to unwrap
    function unwrap(uint256 _id, inEuint128 memory _amount) external {
        euint128 amount = FHE.asEuint128(_amount);
        FHEStorage storage $ = _getFHEStorage();
        euint128 currentBalance = $._privateBalances[_id][msg.sender];

        // Ensure sufficient balance
        FHE.req(FHE.lte(amount, currentBalance));

        $._privateBalances[_id][msg.sender] = FHE.sub(currentBalance, amount);

        uint128 decryptedAmount = FHE.decrypt(amount);
        _mint(msg.sender, _id, uint256(decryptedAmount), "");
    }

    /// @notice Transfers encrypted tokens to another address
    /// @param _to The address to transfer to
    /// @param _id The ID of the token to transfer
    /// @param _amount The encrypted amount to transfer
    function transferEncrypted(address _to, uint256 _id, inEuint128 memory _amount) external {
        euint128 amount = FHE.asEuint128(_amount);
        FHEStorage storage $ = _getFHEStorage();
        euint128 senderBalance = $._privateBalances[_id][msg.sender];

        FHE.req(FHE.lte(amount, senderBalance));

        $._privateBalances[_id][msg.sender] = FHE.sub(senderBalance, amount);

        euint128 receiverBalance = $._privateBalances[_id][_to];
        if (!FHE.isInitialized(receiverBalance)) {
            $._privateBalances[_id][_to] = amount;
        } else {
            $._privateBalances[_id][_to] = FHE.add(receiverBalance, amount);
        }
    }

    /// @notice Returns the encrypted balance of a user (viewable only by user)
    /// @param _account The address of the user
    /// @param _id The ID of the token
    /// @param _auth The permission signature
    /// @return The decrypted balance
    function balanceOfEncrypted(address _account, uint256 _id, Permission memory _auth)
        external
        view
        onlySender(_auth)
        returns (uint256)
    {
        if (msg.sender != _account) revert Listing__AccountMustBeCaller();

        FHEStorage storage $ = _getFHEStorage();
        if (!FHE.isInitialized($._privateBalances[_id][_account])) {
            return 0;
        }
        return uint256(FHE.decrypt($._privateBalances[_id][_account]));
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
