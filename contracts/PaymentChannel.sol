pragma solidity ^0.5.0;

import "./SafeMath.sol";

contract PaymentChannel {

using SafeMath for uint256;

  struct Channel {
    bytes32 id;
    address sender;
    address recipient;
    uint lockUntil;
    uint256 balance;
    bool isOpen;
  }


    mapping (bytes32=>mapping(uint=>bool)) noncePaid;
    mapping (address=>mapping(uint=>bytes32)) userChannels;
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
    emit DepositToChannel(id, msg.sender, msg.value);
  }

}