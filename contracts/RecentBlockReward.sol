// Copyright 2018 Parity Technologies (UK) Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Recent block reward contract.

pragma solidity ^0.5.0;

import "./BlockReward.sol";


contract RecentBlockReward is BlockReward {
	address systemAddress;

	uint lastClaimedIssuanceBlock;
	uint256 maxReward = 10 ether;
	uint halvingEvery = 12614400;

	modifier onlySystem {
		require(msg.sender == systemAddress);
		_;
	}

	constructor (address _systemAddress) public {
		/* systemAddress = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE; */
		systemAddress = _systemAddress;
	}

	function calculateReward(uint issuanceBlock) private returns (uint256) {
		require(lastClaimedIssuanceBlock < issuanceBlock);
		uint divisor = (issuanceBlock / halvingEvery) + 1;
		uint blockReward = maxReward / divisor;
		uint multiplier = 1;
		if (lastClaimedIssuanceBlock > 0) {
			multiplier = issuanceBlock - lastClaimedIssuanceBlock;
		}
		uint totalReward = multiplier * blockReward;
		require(totalReward > 0);
		lastClaimedIssuanceBlock = issuanceBlock;
		return totalReward;
	}


	// produce rewards for the given benefactors, with corresponding reward codes.
	// only callable by `SYSTEM_ADDRESS`
	function reward(address[] calldata benefactors, uint16[] calldata kind) external onlySystem returns (address[] memory, uint256[] memory) {
		require(benefactors.length == kind.length);
		uint256 calculateRewardValue = calculateReward(block.number);
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
