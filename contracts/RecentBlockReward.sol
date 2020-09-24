/* 
RE-Cent Block reward Smart Contract v.1.0.0
Author: Giannis Zarifis <jzarifis@gmail.com>
*/

pragma solidity ^0.5.0;

import "./BlockReward.sol";
import "./RecentBlockchain.sol";

//Smart contract that produce rewards when a new Block is mined by Validators
contract RecentBlockReward is BlockReward, RecentBlockchain {
    //System address allowed to call reward method
    address systemAddress;

    //Last mined Block that produced rewards
    uint256 lastClaimedIssuanceBlock;

    modifier onlySystem {
        require(msg.sender == systemAddress);
        _;
    }

    constructor() public {
        systemAddress = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;
    }

    // produce rewards for the given benefactors, with corresponding reward codes.
    // only callable by `SYSTEM_ADDRESS`
    function reward(address[] calldata benefactors, uint16[] calldata kind)
        external
        onlySystem
        returns (address[] memory, uint256[] memory)
    {
        require(benefactors.length == kind.length);
        //Calculate the reward
        uint256 calculateRewardValue = calculateReward(
            block.number,
            lastClaimedIssuanceBlock
        );
        uint256[] memory rewards = new uint256[](benefactors.length);

        //Iterate and produce Reward only for Miners
        for (uint256 i = 0; i < benefactors.length; i++) {
            if (kind[i] == 0) {
                rewards[i] = calculateRewardValue;
            } else {
                rewards[i] = 0;
            }
        }
        return (benefactors, rewards);
    }
}
