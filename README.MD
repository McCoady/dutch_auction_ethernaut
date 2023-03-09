# Dutch Auction NFT

A practice implementation of a dutch auction NFT (not recommended for use in production) where initial mint price starts at 1 ether and drops 0.05 ethers every 10 minutes until it stops at 0.1 ether. If not already sold out, the minting period can be ended by anyone 48 hours after the start of the auction. Collection size is set to 500.

Contract allows users to reclaim the difference between their mint price & final price after the auction ends. Also refunds user (within mint tx) if sent too much eth (for example if the price decremented while pending).

The contract also only allows the owner to withdraw funds equalling finalPrice * totalSupply, so they can't pull the funds of someone who's yet to reclaim their funds.

The contract allows a max of 3 tokens minted per wallet.

## Dependencies

This contract uses the Solmate ERC721 contract & LibString library, as well as the openzeppelin Ownable & ReentrancyGuard contracts.

## Considerations
Dutch auctions can been seen as giving an unfair advantage to those who're familiar with the mempool as they're able to track how many transactions are coming to the contract to estimate where the final price will be (and thus also estimate the potential secondary demand for the tokens upon sellout), while others have to go in blind.

Should there be a time after which the owner can withdraw non-refunded funds? Or push them back to the people due refunds?

Is there any way funds can get locked in the contract?
