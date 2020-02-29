 /* 
RE-Cent OffChain-Transactions/Payment Channels Smart Contract v.1.0.0
Author: Giannis Zarifis <jzarifis@gmail.com>
*/


pragma solidity ^0.5.0;

import "./RecentBlockchain.sol";

contract PaymentChannels is RecentBlockchain {

  /**
    * Constructor function
    * Initializes PaymentChannel contract
  */
  constructor() public {
  }

  //P2P channels
  struct Channel {
    bytes32 id;
    address payable sender;
    address payable recipient;
    uint lockUntil;
    uint256 balance;
    bool isOpen;
  }
  mapping (bytes32=>mapping(bytes32=>uint256)) noncePaidAmount;
  mapping (address=>mapping(uint=>bytes32)) userChannels;
  mapping (bytes32=>Channel) channels;
  mapping (address=>uint) numberOfUserChannels;
  // Notifies that a new Channel was opened
  event ChannelOpened(bytes32 id, address indexed sender, address indexed recipient, uint256 amount);

  // Notifies for a deposit to a Channel
  event DepositToChannel(bytes32 id, address indexed sender, uint256 amount);

  // Notifies for Channel closed
  event ChannelClosed(bytes32 id, address indexed sender, uint256 amount);

  // Notifies for Off-chain transaction finalized
  event P2POffChainTransaction(bytes32 indexed channelId, address indexed sender, address indexed recipient, uint256 recipientAmount);

  /**
     * Open a new channel
  */
  function openChannel(address payable recipient, uint lockTimeInDays) public payable
  {
    require(msg.value > 0);
    require(recipient != msg.sender);
    Channel memory newChannel;
    newChannel.id = keccak256(abi.encodePacked(msg.sender, recipient, now)); 
    userChannels[msg.sender][numberOfUserChannels[msg.sender]] = newChannel.id;
    numberOfUserChannels[msg.sender] += 1;
    
    newChannel.balance += msg.value;
    newChannel.sender = msg.sender;
    newChannel.recipient = recipient;
    newChannel.isOpen = true;
    newChannel.lockUntil = now + lockTimeInDays * 1 days;
    channels[newChannel.id] = newChannel;
    emit ChannelOpened(newChannel.id, msg.sender, recipient, msg.value);
  }

  /**
     * Deposit a new channel
  */
  function depositToChannel(bytes32 id, uint increaseLckTimeInDays) public payable
  {
    require(msg.value > 0);
    require(channels[id].sender == msg.sender);
    require(increaseLckTimeInDays >= 0);
    require(channels[id].isOpen);

    channels[id].balance += msg.value;
    channels[id].lockUntil = channels[id].lockUntil + increaseLckTimeInDays * 1 days;
    emit DepositToChannel(id, msg.sender, msg.value);
  }

  /**
     * Close a new channel
  */
  function closeChannel(bytes32 id) public
  {
    require(channels[id].balance > 0, "Insufficient balance");
    require(channels[id].sender == msg.sender, "Message signer isn't the owner of channel");
    require(channels[id].lockUntil < now,"Balance locked");
    uint256 amount = channels[id].balance; 
    channels[id].balance = 0;
    channels[id].isOpen = false;
    msg.sender.transfer(amount);
    emit ChannelClosed(id, msg.sender, amount);
  }

  /**
     * Finalize P2P Off-chain transaction
  */
  function finalizeOffchainP2PTransaction(bytes32 h,
		uint8   v,
		bytes32 r,
		bytes32 s,
		bytes32 channelId,
		bytes32 nonce,
		uint256 amount) public
  {
    bytes32 proof = keccak256(abi.encodePacked(channelId, nonce, amount));
    //bytes32 prefixedProof = keccak256(abi.encode(prefix, proof));
    require(proof == h, "Off-chain transaction hash does't match with payload");
    address signer = ecrecover(h, v, r, s);
    require(signer == channels[channelId].sender, "Signer should be the channel creator");
    require(noncePaidAmount[channelId][nonce] < amount, "Requested amount should be greater than the previous finalized for P2P content transaction");
    uint256 amountToBeTransferred =  amount - noncePaidAmount[channelId][nonce];
    noncePaidAmount[channelId][nonce] = amount; 
    require(channels[channelId].balance >= amountToBeTransferred, "Insufficient balance");
    channels[channelId].balance -= amountToBeTransferred;
    address payable channelRecipient = channels[channelId].recipient;
    channelRecipient.transfer(amountToBeTransferred);
    emit P2POffChainTransaction(channelId, signer, channelRecipient, amountToBeTransferred);   
  }

  function getChannelId (uint userChannelId) public view returns (bytes32) {
    return userChannels[msg.sender][userChannelId];
  }

  function getUserTotalChannels () public view returns (uint) {
    return numberOfUserChannels[msg.sender];
  }


    struct Relayer {

    string name;
    address payable owner;
    string domain;

    uint maxUsers;
    uint256 maxCoins;
    uint maxTxThroughput;

    uint currentUsers;
    uint256 currentCoins;
    uint currentTxThroughput;

    uint offchainTxDelay;
    //Thousands percent
    uint fee;

    uint256 remainingPenaltyFunds;
  }

  //Per epoch
  mapping(uint=>uint) public relayersCounter ;

  //mapping(uint=>mapping (address=>Relayer)) public epochRelayers;

  mapping(uint=>mapping (uint=>Relayer)) public relayers;

  mapping(uint=>mapping (address=>uint)) public epochRelayerIndex;


  // Notifies for a new Relayer as candidate
  event RelayerProposed(uint indexed epoch, address indexed relayer, string  domain, address indexed owner, string name, uint fee, uint offchainTxDelay);

  // Notifies for Relayer updated
  event RelayerUpdated(uint indexed epoch, address indexed relayer, string  domain, string name, uint fee, uint offchainTxDelay);

  // Notifies for Relayer withdrawal of penalty funds
  event RelayerWithdrawFunds(uint indexed epoch, address indexed relayer, uint256 amount);

  /**
     * Relayer as candidate
  */
  function requestRelayerLicense(uint targetEpoch, string memory domain, string memory name, uint fee, uint maxUsers, uint256 maxCoins, uint maxTxThroughput, uint offchainTxDelay) public payable {
    if (targetEpoch > 1) {
      require(block.number < getCurrentRelayersElectionEnd(), "Relayers election period has passed");
      require(targetEpoch > getCurrentEpoch(), "Target epoch should be greater than current");
    }

    uint256 requiredAmount = getFundRequiredForRelayer(maxUsers, maxCoins, maxTxThroughput);
    require(requiredAmount <= msg.value,"Invalid required amount");
    
    require(maxUsers > 0, "maxUsers should be greater than 0");
    require(maxCoins > 0, "maxCoins should be greater than 0");
    require(maxTxThroughput > 0, "maxTxThroughput should be greater than 0");
    require(offchainTxDelay > 0, "offchainTxDelay should be greater than 0");
    require(fee < 1000, "Fee should be lower than 1000");

    require(epochRelayerIndex[targetEpoch][msg.sender] == 0 , "Already registered Relayer as candidate");

    uint currentRelayersNumber = relayersCounter[targetEpoch];

    if (currentRelayersNumber >= maximumRelayersNumber) {
      address payable toBeReplacedRelayer = address(0);
      uint toBeReplacedRelayerIndex = 0;
      for (uint i=0; i<currentRelayersNumber; i++) {
        
        if (relayers[targetEpoch][i].remainingPenaltyFunds < msg.value) {
          toBeReplacedRelayer = address(uint160(relayers[targetEpoch][i].owner));
          toBeReplacedRelayerIndex = i;
          break;
        } 
      }

      if (toBeReplacedRelayer==address(0)) {
        revert("Relayers list is full");
      }
      //epochRelayers[targetEpoch][toBeReplacedRelayer] = relayer;
      uint256 refund = relayers[targetEpoch][toBeReplacedRelayerIndex].remainingPenaltyFunds;
      epochRelayerIndex[targetEpoch][toBeReplacedRelayer] = 0;
      relayers[targetEpoch][toBeReplacedRelayerIndex].fee = fee;
      relayers[targetEpoch][toBeReplacedRelayerIndex].maxUsers = maxUsers;
      relayers[targetEpoch][toBeReplacedRelayerIndex].maxCoins = maxCoins;
      relayers[targetEpoch][toBeReplacedRelayerIndex].maxTxThroughput = maxTxThroughput;
      relayers[targetEpoch][toBeReplacedRelayerIndex].offchainTxDelay = offchainTxDelay;
      relayers[targetEpoch][toBeReplacedRelayerIndex].remainingPenaltyFunds = requiredAmount;
      relayers[targetEpoch][toBeReplacedRelayerIndex].name = name;
      relayers[targetEpoch][toBeReplacedRelayerIndex]. domain = domain;
      relayers[targetEpoch][toBeReplacedRelayerIndex].owner = msg.sender;
      epochRelayerIndex[targetEpoch][msg.sender] = toBeReplacedRelayerIndex;
      toBeReplacedRelayer.transfer(refund);
    } else {
      relayersCounter[targetEpoch]++;
      uint index = relayersCounter[targetEpoch];
      relayers[targetEpoch][index].fee = fee;
      relayers[targetEpoch][index].maxUsers = maxUsers;
      relayers[targetEpoch][index].maxCoins = maxCoins;
      relayers[targetEpoch][index].maxTxThroughput = maxTxThroughput;
      relayers[targetEpoch][index].offchainTxDelay = offchainTxDelay;
      relayers[targetEpoch][index].remainingPenaltyFunds = requiredAmount;
      relayers[targetEpoch][index].name = name;
      relayers[targetEpoch][index]. domain = domain;
      relayers[targetEpoch][index].owner = msg.sender;
      epochRelayerIndex[targetEpoch][msg.sender] = index;
    }

    emit RelayerProposed(targetEpoch, msg.sender, domain, msg.sender, name, fee, offchainTxDelay);    
  }

  function testHashing(bytes32 id, string memory domain) public pure returns (bool,bytes32,bytes32) {
      bytes32 lid = keccak256(abi.encodePacked(domain));
      return (lid==id, id, lid );
    }




  /**
     * Update Relayer
  */
  function updateRelayer(uint targetEpoch, string memory domain, string memory name, uint fee, uint offchainTxDelay) public {
    uint index = epochRelayerIndex[targetEpoch][msg.sender];
    require(index > 0, "Relayer not found");
    require(fee < 1000, "Fee should be lower than 1000");


    relayers[targetEpoch][index].domain = domain;
    relayers[targetEpoch][index].name = name;
    relayers[targetEpoch][index].fee = fee;
    relayers[targetEpoch][index].offchainTxDelay = offchainTxDelay;
    emit RelayerUpdated(targetEpoch, msg.sender, domain, name, fee, offchainTxDelay);
  }

  
  /**
     * withdraw from Relayer
  */
  function relayerWithdrawPenaltyFunds(uint targetEpoch) public
  {
    uint index = epochRelayerIndex[targetEpoch][msg.sender];
    require(index > 0, "Relayer not found");
    uint currentEpoch = getCurrentEpoch();
    require(targetEpoch + 1 < currentEpoch, "Current epoch should be lower than requested epoch");

    uint256 remainingAmount = relayers[targetEpoch][index].remainingPenaltyFunds;
    require(remainingAmount > 0, "Insufficient balance");
    

    relayers[targetEpoch][index].remainingPenaltyFunds = 0;

    msg.sender.transfer(remainingAmount);
    emit RelayerWithdrawFunds(targetEpoch, msg.sender, remainingAmount);   
  }
  


  //Relayer Deposits
  struct DepositOnRelayer {
    uint lockUntilBlock;
    uint256 balance;
  }

  mapping (address => mapping (address => DepositOnRelayer)) public userDepositOnRelayer;

  // Per user => beneficiary => nonce finalized amount 
  mapping (address => mapping (address => mapping (bytes32 => uint256))) public userToBeneficiaryFinalizedAmountForNonce;

  // Notifies for user deposit on Relayer
  event UserDeposit(address indexed relayer, address indexed user, uint256 amount);

  // Notifies for user withdraw on Relayer
  event UserWithdraw(address indexed relayer, address indexed user, uint256 amount);

  // Notifies for Off-chain transaction finalized
  event RelayedOffChainTransaction(address indexed relayer, address indexed user, address indexed beneficiary, uint256 relayerFee, uint256 beneficiaryAmount, bool isPayedFromPenaltyFunds);

  /**
     * deposit to Relayer
  */
  function depositToRelayer(address relayerId, uint lockUntilBlock) public payable
  {
    uint targetEpoch = getCurrentEpoch();
    uint index = epochRelayerIndex[targetEpoch][relayerId];
    require(index > 0, "Relayer not found");
    require(relayers[targetEpoch][index].remainingPenaltyFunds > 0, "Relayer doesn't have any remaining penalty funds");
    require(msg.value > 0, "Deposit amount should be greater then 0");
    require(lockUntilBlock > block.number, "The lockTimeInDays should be greater than zero");
    
    if (userDepositOnRelayer[msg.sender][relayerId].lockUntilBlock == 0) {
      relayers[targetEpoch][index].currentUsers += 1;
    }
    userDepositOnRelayer[msg.sender][relayerId].lockUntilBlock = lockUntilBlock;
    require(relayers[targetEpoch][index].currentUsers <= relayers[targetEpoch][index].maxUsers, "Max users limit violated");

    relayers[targetEpoch][index].currentCoins += msg.value;

    require(relayers[targetEpoch][index].currentCoins <= relayers[targetEpoch][index].maxCoins, "Max coins limit violated");
    userDepositOnRelayer[msg.sender][relayerId].balance += msg.value;
    emit UserDeposit(relayerId, msg.sender, msg.value);
  }

  /**
     * withdraw from Relayer
  */
  function withdrawFunds(address relayerId, uint256 amount) public
  {


    require(userDepositOnRelayer[msg.sender][relayerId].lockUntilBlock < block.number, "Balance locked");
    require(userDepositOnRelayer[msg.sender][relayerId].balance >= amount, "Insufficient balance");
    userDepositOnRelayer[msg.sender][relayerId].balance -= amount;

    msg.sender.transfer(amount);
    emit UserWithdraw(relayerId, msg.sender, amount);   
  }


  /**
     * check offchain payment 
  */
  function checkOffchainSignature(
    bytes32 h,
		uint8   v,
		bytes32 r,
		bytes32 s,
		bytes32 nonce,
    uint fee,
    address payable beneficiary,
		uint256 amount) public pure returns (address signer)
  {
    bytes32 proof = keccak256(abi.encodePacked( beneficiary, nonce, amount, fee));
    require(proof == h, "Off-chain transaction hash does't match with payload");
    signer = ecrecover(h, v, r, s);

    return signer;
  }


  /**
     * check offchain payment complete
  */
  function checkOffchainRelayerSignature(
    bytes32 proof,
    bytes32 rh,
	  uint8   rv,
	  bytes32 rr,
	  bytes32 rs,
    uint txUntilBlock) public pure returns (address payable relayerid)
  {
    bytes32 relayerProof = keccak256(abi.encodePacked(proof, txUntilBlock));
    require(relayerProof == rh, "Off-chain transaction hash does't match with payload");
    address relayer = ecrecover(rh, rv, rr, rs);
    relayerid =  address(uint160((relayer)));
    return relayerid;
  }


  function getFundRequiredForRelayer(uint maxUsers, uint256 maxCoins, uint maxTxThroughputPer100000Blocks) public pure returns (uint256 requiredAmount)
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

        // //Remove divide
        // return requiredAmount.div(100000);
	}

  // /**
  //    * check offchain payment
  // */
  // function getFinalizeOffchainRelayerSignature(
	// 	address relayerId,
	// 	bytes32 nonce,
  //   uint fee,
  //   address payable beneficiary,
	// 	uint256 amount) public pure returns (bytes32 proof)
  // {
  //   return keccak256(abi.encodePacked(relayerId, beneficiary, nonce, amount, fee));
  //   //return keccak256(abi.encode(prefix, proof));
  // }

  /**
     * execute offchain payment
  */
  function finalizeOffchainRelayerTransaction(
    bytes32 h,
		uint8   v,
		bytes32 r,
		bytes32 s,
    bytes32 rh,
		uint8   rv,
		bytes32 rr,
		bytes32 rs,
		bytes32 nonce,
    uint fee,
    uint txUntilBlock,
    address payable beneficiary,
		uint256 amount) public
  {

    
    address signer = checkOffchainSignature(h, v, r, s, nonce, fee, beneficiary, amount );
    address payable relayerId = checkOffchainRelayerSignature(h, rh, rv, rr, rs, txUntilBlock);

    uint epoch = getEpochByBlock(txUntilBlock);
    uint index = epochRelayerIndex[epoch][relayerId];
    if (index==0 && epoch >1 )
    {
      epoch = epoch-1;
      index = epochRelayerIndex[epoch][relayerId];
    }
    require(index > 0, "Relayer not found");


    require(userToBeneficiaryFinalizedAmountForNonce[signer][beneficiary][nonce] < amount, "Requested amount should be greater than the previous finalized for withdraw request or P2P content transaction");
    uint256 amountToBeTransferred =  amount - userToBeneficiaryFinalizedAmountForNonce[signer][beneficiary][nonce];
    userToBeneficiaryFinalizedAmountForNonce[signer][beneficiary][nonce] = amount; 
    require(userDepositOnRelayer[signer][relayerId].balance >= amountToBeTransferred, "Insufficient balance");
    uint256 relayerFee = 0;
    bool isPayedFromPenaltyFunds = false;
    if (txUntilBlock >= block.number) {
      userDepositOnRelayer[signer][relayerId].balance -= amountToBeTransferred;
      relayerFee = amountToBeTransferred.mulByFraction(fee, 1000);
    } else {
      isPayedFromPenaltyFunds = true;
      relayers[epoch][index].remainingPenaltyFunds -= amountToBeTransferred;
    }

    beneficiary.transfer(amountToBeTransferred - relayerFee);
    if (relayerFee > 0) {
      relayerId.transfer(relayerFee);
    }
      
    emit RelayedOffChainTransaction(relayerId, signer, beneficiary, relayerFee, amountToBeTransferred, isPayedFromPenaltyFunds);   
  }

}