pragma solidity ^0.5.0;

import "./SafeMath.sol";

contract PaymentChannel {

bytes private prefix = "\x19RecentOT Signed Message:\n32";  

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
    newChannel.id = keccak256(abi.encode(msg.sender, recipient, now)); 
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
    bytes32 proof = keccak256(abi.encode(channelId, nonce, amount));
    bytes32 prefixedProof = keccak256(abi.encode(prefix, proof));
    require(prefixedProof == h, "Off-chain transaction hash does't match with payload");
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
    bytes32 name;
    address payable owner;
    string domain;
    bool isActive;
    //Thousand percent
    uint fee;
    uint totalPoints;     
    uint totalVotes;
  }

  uint relayersCounter = 0;
  mapping (bytes32=>Relayer) relayer;

  mapping (address => mapping (bytes32 => uint)) public userVotesForRelayer;

  // Notifies for a new Relayer
  event RelayerAdded(bytes32 indexed id, string indexed domain, address indexed owner, bytes32 name, uint fee, bool isActive);

  // Notifies for Relayer updated
  event RelayerUpdated(bytes32 indexed id, bytes32 name, uint fee, bool isActive);

  // Notifies for Relayer voted
  event RelayerVoted(bytes32 indexed id, address indexed user, uint rating);

  /**
     * Add a new Relayer
  */
  function addRelayer(string memory domain, bytes32 name, bool isActive, uint fee) public
  {
    bytes32 id = keccak256(abi.encode(domain));
    require(relayer[id].owner == address(0), "Already registered Relayer domain");
    require(fee < 1000, "Fee should be lower than 1000");
    relayer[id].name = name;
    relayer[id].domain = domain;
    relayer[id].isActive = isActive;
    relayer[id].owner = msg.sender;
    relayer[id].fee = fee;
    relayersCounter++;
    emit RelayerAdded(id, domain, msg.sender, name, fee, isActive);
    
  }

  /**
     * Update a new Relayer
  */
  function updateRelayer(bytes32 id, bytes32 name, uint fee, bool isActive) public
  {
    require(relayer[id].owner != address(0), "Relayer not found");
    require(relayer[id].owner == msg.sender, "You are not the owner of Relayer");
    require(fee < 1000, "Fee should be lower than 1000");
    relayer[id].name = name;
    relayer[id].isActive = isActive;
    relayer[id].fee = fee;
    emit RelayerUpdated(id, name, fee, isActive);
  }

  /**
     * vote Relayer
  */
  function voteRelayer(bytes32 id, uint rating) public
  {
    require(rating > 0 && rating <= 500, "Rating should be greater than zero and lower than 500");
    require(userDepositOnRelayer[msg.sender][id].lockUntil > 0, "User has never transacted to this relayer");
    if (userVotesForRelayer[msg.sender][id] == 0 ) {
        relayer[id].totalPoints += rating;
        relayer[id].totalVotes += 1;     
    } else {
        relayer[id].totalPoints += rating;
        relayer[id].totalPoints -= userVotesForRelayer[msg.sender][id];        
    }
    userVotesForRelayer[msg.sender][id] = rating;
    emit RelayerVoted(id, msg.sender, rating);
  }

  /**
      * Get user Rating
  */
  function getRelayerRating(bytes32 id) public view returns(uint relayerRating) {
      uint rating = 0;
      if (relayer[id].totalVotes > 0) {
          rating = relayer[id].totalPoints / relayer[id].totalVotes;
      }
      return (rating);
  }


  //Relayer Deposits
  struct DepositOnRelayer {
    uint lockUntil;
    uint256 balance;
  }

  mapping (address => mapping (bytes32 => DepositOnRelayer)) public userDepositOnRelayer;

  // Per user => beneficiary => nonce finalized amount 
  mapping (address => mapping (address => mapping (bytes32 => uint256))) public userToBeneficiaryFinalizedAmountForNonce;

  // Notifies for user deposit on Relayer
  event UserDeposit(bytes32 indexed id, address indexed user, uint256 amount);

  // Notifies for user withdraw on Relayer
  event UserWithdraw(bytes32 indexed id, address indexed user, uint256 amount);

  // Notifies for Off-chain transaction finalized
  event RelayedOffChainTransaction(bytes32 indexed id, address indexed user, address indexed beneficiary, uint256 relayerFee, uint256 beneficiaryAmount, bool isWithdraw);

  /**
     * deposit to Relayer
  */
  function depositToRelayer(bytes32 id, uint lockTimeInDays) public payable
  {
    require(lockTimeInDays > 0, "The lockTimeInDays should be greater than zero");
    require(relayer[id].isActive, "Relayer not existed or inactive");
    userDepositOnRelayer[msg.sender][id].lockUntil = now + lockTimeInDays * 1 days;
    userDepositOnRelayer[msg.sender][id].balance += msg.value;
    emit UserDeposit(id, msg.sender, msg.value);
  }

  /**
     * withdraw from Relayer
  */
  function withdrawFunds(bytes32 id, uint256 amount) public
  {
    require(userDepositOnRelayer[msg.sender][id].lockUntil < now, "Balance locked");
    require(userDepositOnRelayer[msg.sender][id].balance >= amount, "Insufficient balance");
    userDepositOnRelayer[msg.sender][id].balance -= amount;
    msg.sender.transfer(amount);
    emit UserWithdraw(id, msg.sender, amount);   
  }

  /**
     * withdraw from Relayer
  */
  function finalizeOffchainRelayerTransaction(bytes32 h,
		uint8   v,
		bytes32 r,
		bytes32 s,
		bytes32 relayerId,
		bytes32 nonce,
    address payable beneficiary,
		uint256 amount) public
  {
    require(relayer[relayerId].owner == msg.sender, "Relayer doesn't match with message signer");
    bytes32 proof = keccak256(abi.encode(relayerId, beneficiary, nonce, amount));
    bytes32 prefixedProof = keccak256(abi.encode(prefix, proof));
    require(prefixedProof == h, "Off-chain transaction hash does't match with payload");
    address signer = ecrecover(h, v, r, s);
    require(userToBeneficiaryFinalizedAmountForNonce[signer][beneficiary][nonce] < amount, "Requested amount should be greater than the previous finalized for withdraw request or P2P content transaction");
    uint256 amountToBeTransferred =  amount - userToBeneficiaryFinalizedAmountForNonce[signer][beneficiary][nonce];
    userToBeneficiaryFinalizedAmountForNonce[signer][beneficiary][nonce] = amount; 
    require(userDepositOnRelayer[signer][relayerId].balance >= amountToBeTransferred, "Insufficient balance");
    userDepositOnRelayer[signer][relayerId].balance -= amountToBeTransferred;
    uint256 relayerFee = amountToBeTransferred.mulByFraction(relayer[relayerId].fee, 1000);

    beneficiary.transfer(amountToBeTransferred - relayerFee);
    relayer[relayerId].owner.transfer(relayerFee);
    emit RelayedOffChainTransaction(relayerId, signer, beneficiary, relayerFee, amountToBeTransferred, signer==beneficiary);   
  }

}