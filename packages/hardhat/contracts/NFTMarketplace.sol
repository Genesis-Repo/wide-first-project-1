// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract NFTMarketplace is ERC721Enumerable {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    address public owner;
    uint256 public royaltyFee; // Royalty fee in percentage

    mapping(uint256 => uint256) private _tokenRoyalties; // Royalty fee for each token
    mapping(uint256 => address) private _tokenCreators; // Creator of each token
    EnumerableMap.UintToAddressMap private _tokenRoyaltyRecipients; // Royalty recipients for each token
    mapping(uint256 => uint256) private _tokenResaleFee; // Resale fee for secondary sales

    event RoyaltySet(uint256 indexed tokenId, uint256 royaltyFee, address royaltyRecipient);
    event NFTSold(address buyer, uint256 tokenId, uint256 price);
    event ResaleFeeSet(uint256 indexed tokenId, uint256 resaleFee);

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        owner = msg.sender;
        royaltyFee = 5; // 5% royalty fee by default
    }

    function setRoyalty(uint256 tokenId, uint256 royaltyFee, address royaltyRecipient) public {
        require(_exists(tokenId), "Token does not exist");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");

        _tokenRoyalties[tokenId] = royaltyFee;
        _tokenRoyaltyRecipients.set(tokenId, royaltyRecipient);

        emit RoyaltySet(tokenId, royaltyFee, royaltyRecipient);
    }

    function setResaleFee(uint256 tokenId, uint256 resaleFee) public {
        require(_exists(tokenId), "Token does not exist");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");

        _tokenResaleFee[tokenId] = resaleFee;

        emit ResaleFeeSet(tokenId, resaleFee);
    }

    function buyNFT(uint256 tokenId) public payable {
        require(_exists(tokenId), "Token does not exist");
        address tokenOwner = ownerOf(tokenId);
        require(tokenOwner != address(0), "Invalid token owner");

        uint256 price = msg.value;
        uint256 resaleFee = (price * _tokenResaleFee[tokenId]) / 100;
        uint256 remainingAmount = price - resaleFee;
        
        if (_isApprovedOrOwner(tokenOwner, tokenId)) {
            // Primary sale - send full payment to token owner
            payable(tokenOwner).transfer(remainingAmount);
        } else {
            // Secondary sale - split payment between token owner and royalty fee recipient
            uint256 tokenRoyalty = (remainingAmount * _tokenRoyalties[tokenId]) / 100;
            uint256 amountAfterRoyalty = remainingAmount - tokenRoyalty;
            
            payable(tokenOwner).transfer(amountAfterRoyalty);
            payable(_tokenRoyaltyRecipients.get(tokenId)).transfer(tokenRoyalty);
        }

        _transfer(tokenOwner, _msgSender(), tokenId); // Transfer ownership of token

        emit NFTSold(_msgSender(), tokenId, price);
    }

    function setRoyaltyFee(uint256 newRoyaltyFee) public {
        require(_msgSender() == owner, "Caller is not the owner");
        royaltyFee = newRoyaltyFee;
    }
}