// SPDX-License-Identifier: MIT
/*
 ╔═══════════════════════════════════════════════════════════════════════╗
 ║                                                                       ║
 ║     ██████╗ ██████╗  ██████╗ █████╗  █████╗ ███╗   ███╗██████╗        ║
 ║    ██╔═══██╗██╔══██╗██╔════╝██╔══██╗██╔══██╗████╗ ████║██╔══██╗       ║
 ║    ██║   ██║██████╔╝██║     ███████║███████║██╔████╔██║██████╔╝       ║
 ║    ██║   ██║██╔══██╗██║     ██╔══██║██╔══██║██║╚██╔╝██║██╔══██╗       ║
 ║    ╚██████╔╝██║  ██║╚██████╗██║  ██║██║  ██║██║ ╚═╝ ██║██║  ██║       ║
 ║     ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝       ║
 ║                                                                       ║
 ║    ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀     ║
 ║    ✦ PROJECT: ORCA AMR ECOSYSTEM                                      ║
 ║    ✦ TYPE: METAVERSE REAL ESTATE BONDS                                ║
 ║    ✦ NETWORK: POLYGON (POL)                                           ║
 ║    ✦ DATA: IPFS INTEGRATED                                            ║
 ╚═══════════════════════════════════════════════════════════════════════╝
*/

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Added for safety
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract OrcaAMR_MetaverseHouse is ERC721, ERC721Enumerable, ERC2981, ReentrancyGuard, Ownable {
    using Strings for uint256;

    // ========== IMMUTABLE ADDRESSES (Revenue Split) ==========
    address public constant WALLET_1 = 0xDaD6cdF5198A2790A0bbA9Db0569C5c5B5114626; 
    address public constant WALLET_2 = 0x6Fdd436AA886F4b75e2B351Ff070848218Cf5B57; 
    
    // ========== CONSTANTS ==========
    uint256 public constant MAX_SUPPLY = 5000;
    uint256 public constant HOUSE_SIZE_SQM = 500;
    
    // Initial Price: 10,000 POL 
    uint256 public constant INITIAL_PRICE = 10000 ether; 
    
    // Price Increase: 5%
    uint256 public constant PRICE_INCREASE_BPS = 500; 
    
    // Royalty: 10%
    uint96 public constant ROYALTY_BPS = 1000;
    
    // ========== STATE VARIABLES ==========
    uint256 public currentPrice;
    string public baseURI; // Stores your IPFS link
    string public baseExtension = ".json"; // Assumes files are named 1.json, 2.json
    
    struct HouseData {
        uint256 tokenId;
        uint256 sizeSquareMeters;
        uint256 purchasePrice;
        uint256 purchaseTimestamp;
        address originalOwner;
    }
    
    mapping(uint256 => HouseData) public houses;
    
    // ========== EVENTS ==========
    event HousePurchased(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event BaseURIUpdated(string newBaseURI);

    // ========== CONSTRUCTOR ==========
    constructor() ERC721("ORCAAMR Metaverse House", "ORCA-HOUSE") Ownable(msg.sender) {
        currentPrice = INITIAL_PRICE;
        
        // Setting your IPFS Link here
        // Note: added 'ipfs://' prefix and trailing slash '/' automatically
        baseURI = "ipfs://bafkreide7quwqilu4673c6b4qbgcldwd5lua6v5pvdtoyv3i3f6icdua7m/";
        
        _setDefaultRoyalty(address(this), ROYALTY_BPS);
    }
    
    // ========== MAIN FUNCTION (MINTING) ==========
    function buyHouse() external payable nonReentrant {
        uint256 currentSupply = totalSupply();
        require(currentSupply < MAX_SUPPLY, "All houses sold out");
        require(msg.value >= currentPrice, "Insufficient payment");
        
        uint256 tokenId = currentSupply + 1;
        
        // 1. Revenue Split Calculation
        uint256 share = msg.value / 2;
        
        // 2. Transfers
        (bool sent1, ) = payable(WALLET_1).call{value: share}("");
        require(sent1, "Transfer to wallet 1 failed");
        
        (bool sent2, ) = payable(WALLET_2).call{value: msg.value - share}("");
        require(sent2, "Transfer to wallet 2 failed");
        
        // 3. Mint NFT
        _safeMint(msg.sender, tokenId);
        
        // 4. Store On-Chain Data
        houses[tokenId] = HouseData({
            tokenId: tokenId,
            sizeSquareMeters: HOUSE_SIZE_SQM,
            purchasePrice: msg.value,
            purchaseTimestamp: block.timestamp,
            originalOwner: msg.sender
        });
        
        emit HousePurchased(tokenId, msg.sender, msg.value);
        
        // 5. Price Increase Logic (Bonding Curve)
        uint256 oldPrice = currentPrice;
        currentPrice = currentPrice + (currentPrice * PRICE_INCREASE_BPS / 10000);
        emit PriceUpdated(oldPrice, currentPrice);
        
        // 6. Refund Excess
        if (msg.value > oldPrice) {
            (bool refunded, ) = payable(msg.sender).call{value: msg.value - oldPrice}("");
            require(refunded, "Refund failed");
        }
    }
    
    // ========== METADATA HANDLING ==========
    
    // Internal function required by OpenZeppelin
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // Function to construct the full link (e.g., ipfs://.../1.json)
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
            : "";
    }

    // ========== ADMIN FUNCTIONS (Owner Only) ==========
    
    // Critical: Allows you to update the IPFS link if you upload new folders later
    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
        emit BaseURIUpdated(_newBaseURI);
    }
    
    function setBaseExtension(string memory _newBaseExtension) external onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function withdrawRoyalties() external nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No royalties to withdraw");
        uint256 share = balance / 2;
        (bool sent1, ) = payable(WALLET_1).call{value: share}("");
        require(sent1, "Transfer 1 failed");
        (bool sent2, ) = payable(WALLET_2).call{value: balance - share}("");
        require(sent2, "Transfer 2 failed");
    }
    
    receive() external payable {}
    
    // ========== OVERRIDES ==========
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
