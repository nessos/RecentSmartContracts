pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./RecentBlockchain.sol";

contract PaymentChannels is RecentBlockchain {

//bytes private prefix = "\x19Re-CentT Signed Message:\n32";  

using SafeMath for uint256;

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

  //Relayers
  struct Relayer {
    string name;
    address payable owner;
    string domain;

    uint maxUsers;
    uint maxCoins;
    uint maxTxThroughput;
    uint offchainTxDelay;
    uint epoch;


    //Thousands percent
    uint fee;
  }

  //Per epoch
  mapping(uint=>uint) public relayersCounter ;

  //mapping(uint=>mapping (address=>Relayer)) public epochRelayers;

  mapping(uint=>mapping (uint=>address)) public epochRelayerOwnerByIndex;

  mapping (address=>Relayer) public relayers;

  mapping (address=>uint) public currentRelayerUsers;

  mapping (address=>uint256) public currentRelayerCoins;

  mapping (address=>uint) public currentRelayerTxThroughput;

  mapping (uint=>mapping (address=>uint256)) public relayerDepositPerEpoch;

  // Notifies for a new Relayer
  event RelayerAdded(address indexed relayer, string  domain, address indexed owner, string name, uint fee, uint offchainTxDelay);

  // Notifies for a new Relayer as candidate
  event RelayerProposed(address indexed relayer, string  domain, address indexed owner, uint indexed epoch, string name, uint fee, uint offchainTxDelay);

  // Notifies for Relayer updated
  event RelayerUpdated(address indexed relayer, string  domain, string name, uint fee, uint offchainTxDelay);

  // Notifies for Relayer withdrawal of penalty funds
  event RelayerWithdrawFunds(address indexed relayer, uint epoch, uint256 amount);

  /**
     * Relayer as candidate
  */
  function requestRelayerLicense(string memory domain, string memory name, uint fee, uint maxUsers, uint maxCoins, uint maxTxThroughput, uint offchainTxDelay) public payable {
    
    uint targetEpoch = getTargetEpoch();
    require(targetEpoch > 1, "Canditates allowed after epoch 1");
    require(block.number < getCurrentValidatorsElectionEnd(), "Relayers election period has passed");
    require(relayers[msg.sender].epoch != targetEpoch, "Already registered Relayer as candidate");
    uint256 requiredAmount = getFundRequiredForRelayer(maxUsers, maxCoins, maxTxThroughput);
    require(requiredAmount <= msg.value,"Invalid required amount");
    
    require(maxUsers > 0, "maxUsers should be greater than 0");
    require(maxCoins > 0, "maxCoins should be greater than 0");
    require(maxTxThroughput > 0, "maxTxThroughput should be greater than 0");
    require(offchainTxDelay > 0, "offchainTxDelay should be greater than 0");
    require(fee < 1000, "Fee should be lower than 1000");

    uint currentRelayersNumber = relayersCounter[targetEpoch];
    Relayer storage relayer = relayers[msg.sender];
    relayer.name = name;
    relayer. domain = domain;
    relayer.owner = msg.sender;
    relayer.fee = fee;
    relayer.maxUsers = maxUsers;
    relayer.maxCoins = maxCoins;
    relayer.maxTxThroughput = maxTxThroughput;
    relayer.offchainTxDelay = offchainTxDelay;
    relayer.epoch = targetEpoch;

    if (currentRelayersNumber >= maximumRelayersNumber) {
      address toBeReplacedRelayer = address(0);
      uint toBeReplacedRelayerIndex = 0;
      for (uint i=0; i<currentRelayersNumber; i++) {
        address relayerSelected = epochRelayerOwnerByIndex[targetEpoch][i];
        
        if (relayerDepositPerEpoch[targetEpoch][relayerSelected] < msg.value) {
          toBeReplacedRelayer = relayerSelected;
          toBeReplacedRelayerIndex = i;
          break;
        } 
      }

      if (toBeReplacedRelayer==address(0)) {
        revert("Relayers list is full");
      }
      //epochRelayers[targetEpoch][toBeReplacedRelayer] = relayer;
      epochRelayerOwnerByIndex[targetEpoch][toBeReplacedRelayerIndex]  = msg.sender;

    } else {

      //epochRelayers[targetEpoch][msg.sender] = relayer;
      epochRelayerOwnerByIndex[targetEpoch][relayersCounter[targetEpoch]] = msg.sender;
      relayersCounter[targetEpoch]++;
    }

    



    relayers[msg.sender] = relayer;
    relayerDepositPerEpoch[targetEpoch][msg.sender] += msg.value;

    emit RelayerProposed(msg.sender, domain, msg.sender, targetEpoch, name, fee, offchainTxDelay);    
  }

  function testHashing(bytes32 id, string memory domain) public pure returns (bool,bytes32,bytes32) {
      bytes32 lid = keccak256(abi.encodePacked(domain));
      return (lid==id, id, lid );
    }


  /**
     * Add Relayer
  */
  function addRelayer(string memory domain, string memory name, uint fee, uint maxUsers, uint maxCoins, uint maxTxThroughput, uint offchainTxDelay) public payable {
    
    uint256 requiredAmount = getFundRequiredForRelayer(maxUsers, maxCoins, maxTxThroughput);
    require(requiredAmount <= msg.value,"Invalid required amount");
    uint targetEpoch = getTargetEpoch();
    Relayer storage relayer = relayers[msg.sender];

    require(relayersCounter[targetEpoch] < maximumRelayersNumber,"Relayers list is full");
    require(targetEpoch == 1,"AddRelayer is allowed only on 1st epoch");
    require(relayer.owner == address(0), "Already registered Relayer");
    require(fee < 1000, "Fee should be lower than 1000");

    
    relayer.name = name;
    relayer. domain = domain;
    relayer.owner = msg.sender;
    relayer.fee = fee;
    relayer.maxUsers = maxUsers;
    relayer.maxCoins = maxCoins;
    relayer.maxTxThroughput = maxTxThroughput;
    relayer.offchainTxDelay = offchainTxDelay;
    relayer.epoch = targetEpoch;
    //epochRelayers[targetEpoch][msg.sender] = relayer;
    relayers[msg.sender] = relayer;
    epochRelayerOwnerByIndex[targetEpoch][relayersCounter[targetEpoch]] = msg.sender;
    relayersCounter[targetEpoch]++;

    relayerDepositPerEpoch[targetEpoch][msg.sender] += msg.value;

    emit RelayerAdded(msg.sender, domain, msg.sender, name, fee, offchainTxDelay);    
  }


  


  /**
     * Update Relayer
  */
  function updateRelayer(string memory domain, string memory name, uint fee, uint offchainTxDelay) public {
    Relayer storage relayer = relayers[msg.sender];
    require(relayer.owner != address(0), "Relayer not found");
    require(fee < 1000, "Fee should be lower than 1000");
    relayer.domain = domain;
    relayer.name = name;
    relayer.fee = fee;
    relayer.offchainTxDelay = offchainTxDelay;
    emit RelayerUpdated(msg.sender, domain, name, fee, offchainTxDelay);
  }

  
  /**
     * withdraw from Relayer
  */
  function relayerWithdrawPenaltyFunds(uint epoch) public
  {
    uint currentEpoch = getCurrentEpoch();
    require(epoch < currentEpoch, "Current epoch should be lower than requested epoch");

    uint256 remainingAmount = relayerDepositPerEpoch[epoch][msg.sender];
    require(remainingAmount > 0, "Insufficient balance");
    
    Relayer storage relayer = relayers[msg.sender];
    require(relayer.owner != address(0), "Relayer not found");

    relayerDepositPerEpoch[epoch][msg.sender] = 0;

    msg.sender.transfer(remainingAmount);
    emit RelayerWithdrawFunds(msg.sender, epoch, remainingAmount);   
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
  event RelayedOffChainTransaction(address indexed relayer, address indexed user, address indexed beneficiary, uint256 relayerFee, uint256 beneficiaryAmount, bool isWithdraw);

  /**
     * deposit to Relayer
  */
  function depositToRelayer(address relayerId, uint lockUntilBlock) public payable
  {
    
    uint currentEpoch = getCurrentEpoch();

    Relayer storage relayer = relayers[relayerId];
    require(relayer.epoch == currentEpoch, "Not active relayer for current epoch");
    require(msg.value > 0, "Deposit amount should be greater then 0");
    require(lockUntilBlock > block.number, "The lockTimeInDays should be greater than zero");
    require(relayer.owner != address(0), "Relayer not found");
    userDepositOnRelayer[msg.sender][relayerId].lockUntilBlock = lockUntilBlock;
    if (userDepositOnRelayer[msg.sender][relayerId].balance == 0) {
      currentRelayerUsers[relayerId] += 1;
    }

    require(currentRelayerUsers[relayerId] <= relayer.maxUsers, "Max users limit violated");

    currentRelayerCoins[relayerId] += msg.value;

    require(currentRelayerCoins[relayerId] <= relayer.maxCoins, "Max coins limit violated");
    userDepositOnRelayer[msg.sender][relayerId].balance += msg.value;
    emit UserDeposit(relayerId, msg.sender, msg.value);
  }

  /**
     * withdraw from Relayer
  */
  function withdrawFunds(address relayerId, uint256 amount) public
  {
    Relayer storage relayer = relayers[relayerId];
    require(relayer.owner != address(0), "Relayer not found");
    require(userDepositOnRelayer[msg.sender][relayerId].lockUntilBlock < block.number, "Balance locked");
    require(userDepositOnRelayer[msg.sender][relayerId].balance >= amount, "Insufficient balance");
    userDepositOnRelayer[msg.sender][relayerId].balance -= amount;

    currentRelayerCoins[relayerId] -= amount;
    if (userDepositOnRelayer[msg.sender][relayerId].balance == 0) {
      currentRelayerUsers[relayerId] -= 1;
    }
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

    Relayer storage relayer = relayers[relayerId];
    
    require(relayer.owner == msg.sender, "Relayer doesn't match with message signer");


    // bytes32 proof = keccak256(abi.encodePacked(relayerId, beneficiary, nonce, amount, fee));
    // //bytes32 prefixedProof = keccak256(abi.encode(prefix, proof));
    // require(proof == h, "Off-chain transaction hash does't match with payload");
    // address signer = ecrecover(h, v, r, s);


    require(userToBeneficiaryFinalizedAmountForNonce[signer][beneficiary][nonce] < amount, "Requested amount should be greater than the previous finalized for withdraw request or P2P content transaction");
    uint256 amountToBeTransferred =  amount - userToBeneficiaryFinalizedAmountForNonce[signer][beneficiary][nonce];
    userToBeneficiaryFinalizedAmountForNonce[signer][beneficiary][nonce] = amount; 
    require(userDepositOnRelayer[signer][relayerId].balance >= amountToBeTransferred, "Insufficient balance");
    userDepositOnRelayer[signer][relayerId].balance -= amountToBeTransferred;
    uint256 relayerFee = amountToBeTransferred.mulByFraction(fee, 1000);

    if (userDepositOnRelayer[signer][relayerId].balance == 0) {
      currentRelayerUsers[relayerId] -= 1;
    }
    currentRelayerCoins[relayerId] -= amountToBeTransferred;

    beneficiary.transfer(amountToBeTransferred - relayerFee);
    relayer.owner.transfer(relayerFee);
    emit RelayedOffChainTransaction(relayerId, signer, beneficiary, relayerFee, amountToBeTransferred, signer==beneficiary);   
  }

}