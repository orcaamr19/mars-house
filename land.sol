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
 ║    ✦ PROJECT: ORCA AMR ECOSYSTEM                                      ║
 ║    ✦ ASSET:   METAVERSE LAND PLOTS (TIER 3)                           ║
 ║    ✦ SUPPLY:  500 UNITS                                               ║
 ║    ✦ PRICE:   500 POL (~$50 USD)                                      ║
 ╚═══════════════════════════════════════════════════════════════════════╝
*/

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title OrcaAMR_MetaverseLand
 * @dev Smart Contract for Raw Land Plots in the OrcaAMR Metaverse.
 * Features: Hardcoded Partnership Split, Bonding Curve Pricing, Immutable Logic.
 */
contract OrcaAMR_MetaverseLand is ERC721, ERC721Enumerable, ERC2981, ReentrancyGuard, Ownable {
    using Strings for uint256;

    // =============================================================
    //                    PARTNERSHIP WALLETS
    //          (Immutable/Hardcoded for Trustless Security)
    // =============================================================
    
    address public constant WALLET_1 = 0xDaD6cdF5198A2790A0bbA9Db0569C5c5B5114626; 
    address public constant WALLET_2 = 0x6Fdd436AA886F4b75e2B351Ff070848218Cf5B57; 

    // =============================================================
    //                        CONSTANTS
    // =============================================================

    uint256 public constant MAX_SUPPLY = 500;       // Only 500 Land Plots
    uint256 public constant LAND_SIZE_SQM = 1000;   // 1000 Square Meters
    
    // Initial Price: 500 POL (~$50 USD)
    uint256 public constant INITIAL_PRICE = 500 ether; 
    
    // Price Increase: 5% (500 Basis Points) per sale
    uint256 public constant PRICE_INCREASE_BPS = 500; 
    
    // Royalty: 10% (1000 Basis Points)
    uint96 public constant ROYALTY_BPS = 1000;

    // =============================================================
    //                     STATE VARIABLES
    // =============================================================

    uint256 public currentPrice;
    string public baseURI; 
    string public baseExtension = ".json"; 
    
    struct LandData {
        uint256 tokenId;
        uint256 sizeSquareMeters;
        uint256 purchasePrice;
        uint256 purchaseTimestamp;
        address originalOwner;
    }
    
    mapping(uint256 => LandData) public landPlots;

    // =============================================================
    //                          EVENTS
    // =============================================================

    event LandPurchased(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event BaseURIUpdated(string newBaseURI);

    // =============================================================
    //                       CONSTRUCTOR
    // =============================================================

    constructor() ERC721("ORCAAMR Metaverse Land", "ORCA-LAND") Ownable(msg.sender) {
        currentPrice = INITIAL_PRICE;
        
        // IPFS Link updated as requested.
        // WARNING: Ensure this hash points to a FOLDER containing 1.json, 2.json, etc.
        baseURI = "ipfs://bafkreihhf4aydcypvgel7iuuest2wyfzirdjc5lwlfiyjrtd6rk6nr46ra/";
        
        _setDefaultRoyalty(address(this), ROYALTY_BPS);
    }

    // =============================================================
    //                     MINTING LOGIC
    // =============================================================

    function buyLand() external payable nonReentrant {
        uint256 currentSupply = totalSupply();
        require(currentSupply < MAX_SUPPLY, "All land plots sold out");
        require(msg.value >= currentPrice, "Insufficient payment");
        
        uint256 tokenId = currentSupply + 1;
        
        // --- 1. Revenue Split (50/50) ---
        uint256 share = msg.value / 2;
        
        (bool sent1, ) = payable(WALLET_1).call{value: share}("");
        require(sent1, "Transfer to wallet 1 failed");
        
        (bool sent2, ) = payable(WALLET_2).call{value: msg.value - share}("");
        require(sent2, "Transfer to wallet 2 failed");
        
        // --- 2. Mint NFT ---
        _safeMint(msg.sender, tokenId);
        
        // --- 3. Store Data ---
        landPlots[tokenId] = LandData({
            tokenId: tokenId,
            sizeSquareMeters: LAND_SIZE_SQM,
            purchasePrice: msg.value,
            purchaseTimestamp: block.timestamp,
            originalOwner: msg.sender
        });
        
        emit LandPurchased(tokenId, msg.sender, msg.value);
        
        // --- 4. Increase Price (Bonding Curve) ---
        uint256 oldPrice = currentPrice;
        currentPrice = currentPrice + (currentPrice * PRICE_INCREASE_BPS / 10000);
        emit PriceUpdated(oldPrice, currentPrice);
        
        // --- 5. Refund Excess ---
        if (msg.value > oldPrice) {
            (bool refunded, ) = payable(msg.sender).call{value: msg.value - oldPrice}("");
            require(refunded, "Refund failed");
        }
    }

    // =============================================================
    //                   METADATA FUNCTIONS
    // =============================================================

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
            : "";
    }

    // =============================================================
    //                    ADMIN FUNCTIONS
    // =============================================================

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

    // =============================================================
    //                 SOLIDITY OVERRIDES
    // =============================================================

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
