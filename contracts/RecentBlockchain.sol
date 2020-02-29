pragma solidity ^0.5.0;

import "./SafeMath.sol";

contract RecentBlockchain {

    using SafeMath for uint;



    uint public epochBlocks = 1000000;
    uint public halvingEvery = 1000000;

    

    uint public blocksBeforeValidatorElectionAllowed = 10000;
    uint public blocksBeforeRelayersElectionAllowed = 10000;


    uint public maximumValidatorsNumber = 19;

    uint public maximumRelayersNumber = 20;

    uint public blocksPeriodRegulateThroughput = 1000;

    uint256 public pricePerMb = 0.001 ether;
    uint public witnessRequiredBalancePercent = 3;

    uint256 public maxReward = 0.1 ether;
    uint256 public minReward = 0.000001 ether;

	uint public freeServiceDisputeThreshold = 5000;


    


	function calculateReward(uint issuanceBlock, uint lastClaimedIssuanceBlock) public view returns (uint256) {
		require(lastClaimedIssuanceBlock < issuanceBlock);
		uint divisor = (issuanceBlock / halvingEvery) + 1;
		uint blockReward = maxReward / divisor;
		uint multiplier = 1;
		if (lastClaimedIssuanceBlock > 0) {
			multiplier = issuanceBlock - lastClaimedIssuanceBlock;
		}
		uint totalReward = multiplier * blockReward;
        if (totalReward < minReward) {
            totalReward = minReward;
        }
		lastClaimedIssuanceBlock = issuanceBlock;
		return totalReward;
	}

    function calculateReward(uint epoch) public view returns (uint256) {
        uint  issuanceBlock = epoch.mul(epochBlocks)-1;   
        uint  lastClaimedIssuanceBlock = epoch.mul(epochBlocks)-2; 
		return calculateReward(issuanceBlock, lastClaimedIssuanceBlock);
	}


	function getCurrentEpoch() public view returns (uint epoch)
	{
		return block.number.div(epochBlocks) + 1;
	}

    function getEpochByBlock(uint requestedBlock) public view returns (uint epoch)
	{
		return requestedBlock.div(epochBlocks) + 1;
	}

    function getTargetEpoch() public view returns (uint epoch)
	{
        return getCurrentEpoch() + 1;
	}

    function getCurrentEpochEnd() public view returns (uint epoch)
	{
		return getCurrentEpoch().mul(epochBlocks);
	}

    function getCurrentValidatorsElectionEnd() public view returns (uint epoch)
	{
		return getCurrentEpochEnd().sub(blocksBeforeValidatorElectionAllowed);
	}

    function getCurrentRelayersElectionEnd() public view returns (uint epoch)
	{
		return getCurrentEpochEnd().sub(blocksBeforeRelayersElectionAllowed);
	}

    

}