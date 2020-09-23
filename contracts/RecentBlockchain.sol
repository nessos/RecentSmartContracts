/* 
RE-Cent Base Smart Contract v.1.0.0
Author: Giannis Zarifis <jzarifis@gmail.com>
*/

pragma solidity ^0.5.0;

import "./SafeMath.sol";

//Smart Contract that provides system constants and functions. Inherited by Payment channels, Validators and  Block reward smart contracts
contract RecentBlockchain {

    using SafeMath for uint;


	//Epoch period in blocks
    uint public epochBlocks = 1000000;

	//Block reward halving period in blocks
    uint public halvingEvery = 1000000;

    
	//Number of blocks before current epoch end that Validators election is allowed
    uint public blocksBeforeValidatorElectionAllowed = 10000;

	//Number of blocks before current epoch end that Relayers election is allowed
    uint public blocksBeforeRelayersElectionAllowed = 10000;

	//Maximum allowed number of validators. Should be odd number to protect again chain split
    uint public maximumValidatorsNumber = 19;

	// Maximum allowed number of Relayers
    uint public maximumRelayersNumber = 20;

	//The number of blocks to be used on Tx throughput calculation 
    uint public blocksPeriodRegulateThroughput = 1000;

	//The price in ReCent coins per Mb. Used to calculate the required staking amount of of Service Providers that offer free service voting a Validator
    uint256 public pricePerMb = 0.001 ether;

	//The required percent of staking amount against Witness total balcne on Wintnesses Validator voting. witnessRequiredBalancePercent * Witness address total balance should be greater than staking amount
    uint public witnessRequiredBalancePercent = 3;

	//Maximum reward coins per Block(Initial coin emission rate)
    uint256 public maxReward = 0.1 ether;

	//Minimum reward coins per Block(To be used when reward after halving will less than this amount)
    uint256 public minReward = 0.000001 ether;

	//The period in blocks that disputes against Service providers should have a result
	uint public freeServiceDisputeThreshold = 5000;


    

	//Calculates the Block reward coins given the current halving period
	function calculateReward(uint issuanceBlock, uint lastClaimedIssuanceBlock) public view returns (uint256) {
		
		//Current block shoud be greater than the last claimed Block.
		require(lastClaimedIssuanceBlock < issuanceBlock);

		//Current halving period divisor
		uint divisor = (issuanceBlock / halvingEvery) + 1;

		//THe block reward based of halving period
		uint blockReward = maxReward / divisor;

		//When last claimed Block is the previous Block then reward should be the calculated block reward above.
		uint multiplier = 1;
		if (lastClaimedIssuanceBlock > 0) {
			multiplier = issuanceBlock - lastClaimedIssuanceBlock;
		}

		//If there are unclaimed rewards of not mined previously Blocks the current Validator should get those rewards also in order to keep the Coin emission policy 
		uint totalReward = multiplier * blockReward;

		//If the calculated reward is less than the minimum reward then use the minimum as the reward. This means the after a halving period the minReward will be used
        if (totalReward < minReward) {
            totalReward = minReward;
        }

		//Setup the current block as the last claimed Block
		lastClaimedIssuanceBlock = issuanceBlock;
		return totalReward;
	}

	//Calculates the Block reward coins given the current halving period
    function calculateReward(uint epoch) public view returns (uint256) {
        //The last block of a given halving period		
		uint  issuanceBlock = epoch.mul(epochBlocks)-1;  
		
		//The last normally claimed block before halving period last block
        uint  lastClaimedIssuanceBlock = issuanceBlock - 1; 

		//Get the reward of the last halving period block. Actually this is the reward for the whole period
		return calculateReward(issuanceBlock, lastClaimedIssuanceBlock);
	}


	//Get current epoch
	function getCurrentEpoch() public view returns (uint epoch)
	{
		return block.number.div(epochBlocks) + 1;
	}

	//Get epoch for a Block
    function getEpochByBlock(uint requestedBlock) public view returns (uint epoch)
	{
		return requestedBlock.div(epochBlocks) + 1;
	}

	//Get next Epoch
    function getTargetEpoch() public view returns (uint epoch)
	{
        return getCurrentEpoch() + 1;
	}

	//The Block number tha Current epoch ends
    function getCurrentEpochEnd() public view returns (uint epoch)
	{
		return getCurrentEpoch().mul(epochBlocks);
	}

	//The Block number that current Validators election ends
    function getCurrentValidatorsElectionEnd() public view returns (uint epoch)
	{
		return getCurrentEpochEnd().sub(blocksBeforeValidatorElectionAllowed);
	}

	//The Block number that current Relayers election ends
    function getCurrentRelayersElectionEnd() public view returns (uint epoch)
	{
		return getCurrentEpochEnd().sub(blocksBeforeRelayersElectionAllowed);
	}

    

}