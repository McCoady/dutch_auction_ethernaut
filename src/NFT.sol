// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "solmate/tokens/ERC721.sol";
import "solmate/utils/LibString.sol";

abstract contract NFT is ERC721, Ownable, ReentrancyGuard {
    using LibString for uint256;

    error NonExistantId();

    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable MAX_PER_WALLET;

    uint256 public totalSupply;

    string public uri;

    constructor(uint256 _maxSupply, uint256 _maxPerWallet) {
        MAX_SUPPLY = _maxSupply;
        MAX_PER_WALLET = _maxPerWallet;
    }

    //tokenURI
    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory _uri) {
        if (_tokenId >= totalSupply) revert NonExistantId();

        return string(abi.encodePacked(uri, _tokenId.toString()));
    }

    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        uri = _newBaseURI;
    }
}
