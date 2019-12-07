pragma solidity ^0.5.0;

import "./SafeMath.sol";

contract RecentBlockchain {

    using SafeMath for uint;

    uint public epochBlocks = 1000000;

    uint public blocksBeforeValidatorElectionAllowed = 10000;
    uint public blocksBeforeRelayersElectionAllowed = 10000;


    uint public maximumValidatorsNumber = 20;

    uint public maximumRelayersNumber = 20;

    uint public blocksPeriodRegulateThroughput = 1000;


	function getCurrentEpoch()
		public view returns (uint epoch)
	{
		return block.number.div(epochBlocks) + 1;
	}

    function getTargetEpoch()
		public view returns (uint epoch)
	{
		uint targetEpoch = getCurrentEpoch();
        return targetEpoch == 1 ? 1 : targetEpoch + 1;
	}

    function getCurrentEpochEnd()
    public view returns (uint epoch)
	{
		return getCurrentEpoch().mul(epochBlocks);
	}

    function getCurrentValidatorsElectionEnd()
    public view returns (uint epoch)
	{
		return getCurrentEpochEnd().sub(blocksBeforeValidatorElectionAllowed);
	}

    function getCurrentRelayersElectionEnd()
    public view returns (uint epoch)
	{
		return getCurrentEpochEnd().sub(blocksBeforeRelayersElectionAllowed);
	}

    function getFundRequiredForRelayer(uint maxUsers, uint maxCoins, uint maxTxThroughputPer100000Blocks)
    public pure returns (uint256 requiredAmount)
	{
        if (maxUsers <= 1000) {

            requiredAmount += maxUsers.mul(100 * 1 ether);
        } else {
            requiredAmount += 1000 * 100 * 1 ether;
            maxUsers -= 1000;
            if (maxUsers <= 10000) {
                requiredAmount += maxUsers.mul(50 * 1 ether);
            } else {
                requiredAmount += 10000 * 50 * 1 ether;
                maxUsers -= 10000;
                if (maxUsers <= 100000) {
                    requiredAmount += maxUsers.mul(25 * 1 ether);
                } else {
                    requiredAmount += 100000 * 25 * 1 ether;
                    maxUsers -= 100000;
                    if (maxUsers <= 1000000) {
                        requiredAmount += maxUsers.mulByFraction(125 * 1 ether,10);
                    } else {
                        requiredAmount += 1000000 * (125 / 10) * 1 ether;
                        maxUsers -= 1000000;
                        requiredAmount += maxUsers.mul(10 * 1 ether);
                    }
                }

            }
        }
        
        if (maxCoins <= 1000 * 1 ether) {

            requiredAmount += maxCoins.mulByFraction(500,1000);
        } else {
            requiredAmount += 1000 * 500 / 1000;
            maxCoins -= 1000 * 1 ether;
            if (maxCoins <= 10000 * 1 ether) {
                requiredAmount += maxCoins.mulByFraction(200,1000);
            } else {
                requiredAmount += 10000 * 200 / 1000;
                maxCoins -= 10000 * 1 ether;
                if (maxCoins <= 100000 * 1 ether) {
                    requiredAmount += maxCoins.mulByFraction(100,1000);
                } else {
                    requiredAmount += 100000 * 100 / 1000;
                    maxCoins -= 100000 * 1 ether;
                    if (maxCoins <= 1000000 * 1 ether) {
                        requiredAmount += maxCoins.mulByFraction(10,1000);
                    } else {
                        requiredAmount += 1000000 * 10 / 1000;
                        maxCoins -= 1000000 * 1 ether;
                        requiredAmount += maxCoins.mulByFraction(1,1000);
                    }
                }

            }
        }

        if (maxTxThroughputPer100000Blocks <= 10) {
            requiredAmount += maxTxThroughputPer100000Blocks.mulByFraction(10000 * 1 ether,100000);
        } else {
            requiredAmount += 10 * 10000 * 1 ether / 100000;
            maxTxThroughputPer100000Blocks -= 10;
            if (maxTxThroughputPer100000Blocks <= 1000) {
                requiredAmount += maxTxThroughputPer100000Blocks.mulByFraction(120000 * 1 ether,100000);
            } else {
                requiredAmount += 1000 * 120000 * 1 ether / 100000;
                maxTxThroughputPer100000Blocks -= 1000;
                if (maxTxThroughputPer100000Blocks <= 100000) {
                    requiredAmount += maxTxThroughputPer100000Blocks.mulByFraction(150000 * 1 ether,100000);
                } else {
                    requiredAmount += 100000 * 150000 * 1 ether / 100000;
                    maxTxThroughputPer100000Blocks -= 100000;
                    if (maxTxThroughputPer100000Blocks <= 10000000) {
                        requiredAmount += maxTxThroughputPer100000Blocks.mulByFraction(200000 * 1 ether,100000);
                    } else {
                        requiredAmount += 10000000 * 200000 * 1 ether / 100000;
                        maxTxThroughputPer100000Blocks -= 10000000;
                        requiredAmount += maxTxThroughputPer100000Blocks.mulByFraction(1000000 * 1 ether,100000);
                    }
                }

            }
        }

        //Remove divide
        return requiredAmount.div(100000);
	}

}