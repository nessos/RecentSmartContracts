pragma solidity ^0.5.0;

import "./SafeMath.sol";

contract PaymentChannel {

using SafeMath for uint256;

  struct Channel {
    address sender;
    address recipient;
    uint lockUntil;
    uint256 balance;
    bool isOpen;
  }


    mapping (bytes32=>mapping(uint=>bool)) noncePaid;
    mapping (address=>mapping(uint=>Channel)) userChannels;
    mapping (bytes32=>Channel) channels;
    mapping (address=>uint) numberOfUserChannels;

    // Notifies that a new Channel was opened
    event ChannelOpened(bytes32 id, address indexed sender, address indexed recipient, uint256 amount);

    // Notifies for a deposit to a Channel
    event DepositToChannel(bytes32 id, address indexed sender, uint256 amount);

    /**
     * Constructor function
     * Initializes PaymentChannel contract
    */
    constructor() public {
    }


  /**
     * Open a new channel
  */
  function openChannel(address recipient, uint lockTimeInDays) public payable
  {
    require(msg.value > 0);
    require(recipient != msg.sender);

    

    Channel memory newChannel;
    newChannel.balance += msg.value;
    newChannel.sender = msg.sender;
    newChannel.recipient = recipient;
    newChannel.isOpen = true;
    newChannel.lockUntil = now + lockTimeInDays * 1 days;

    userChannels[msg.sender][numberOfUserChannels[msg.sender]] = newChannel;
    numberOfUserChannels[msg.sender] += 1;
    
    // create a channel with the id being a hash of the data
    bytes32 id = keccak256(abi.encode(msg.sender, recipient, numberOfUserChannels[msg.sender]));

    // add it to storage and lookup
    channels[id] = newChannel;
 

    emit ChannelOpened(id, msg.sender, recipient, msg.value);
  }

/**
     * Open a new channel
  */
  function depositToChannel(bytes32 id, uint increaseLckTimeInDays) public payable
  {
    require(msg.value > 0);
    require(channels[id].sender == msg.sender);
    require(increaseLckTimeInDays >= 0);
    require(channels[id].isOpen);

    channels[id].balance += msg.value;
    channels[id].lockUntil = channels[id].lockUntil + increaseLckTimeInDays * 1 days;

    //userChannels[msg.sender][numberOfUserChannels[msg.sender]] = channels[id];
    emit DepositToChannel(id, msg.sender, msg.value);
  }

}