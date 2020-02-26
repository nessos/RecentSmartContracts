pragma solidity ^0.5.0;

import "./BlockReward.sol";
import "./RecentBlockchain.sol";

contract RecentBlockReward is BlockReward, RecentBlockchain {
	address systemAddress;

	uint lastClaimedIssuanceBlock;


	modifier onlySystem {
		require(msg.sender == systemAddress);
		_;
	}

	constructor () public {
		/* systemAddress = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE; */
		systemAddress = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;
	}



	// produce rewards for the given benefactors, with corresponding reward codes.
	// only callable by `SYSTEM_ADDRESS`
	function reward(address[] calldata benefactors, uint16[] calldata kind) external onlySystem returns (address[] memory, uint256[] memory) {
		require(benefactors.length == kind.length);
		uint256 calculateRewardValue = calculateReward(block.number, lastClaimedIssuanceBlock);
		uint256[] memory rewards = new uint256[](benefactors.length);
		for (uint i = 0; i < benefactors.length; i++) {
			if (kind[i]==0) {
				rewards[i] = calculateRewardValue;
			} else {
				rewards[i] = 0;
			}
		}
		return (benefactors, rewards);
	}
}
