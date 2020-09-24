/* 
RE-Cent OffChain-Transactions/Payment Channels Smart Contract v.1.0.0
Author: Giannis Zarifis <jzarifis@gmail.com>
*/

pragma solidity ^0.5.0;

import "./RecentBlockchain.sol";

//Smart Contract for P2P Payment channels and Relayers Payment channels. Inherits RecentBlockchain
contract PaymentChannels is RecentBlockchain {
    constructor() public {}

    //P2P channels structure
    struct Channel {
        //Channel hash/Id
        bytes32 id;
        //Channel Owner
        address payable sender;
        //Recipient Peer
        address payable recipient;
        //Lock until Timestamp
        uint256 lockUntil;
        //Remaining Balance
        uint256 balance;
        //State Open or Close
        bool isOpen;
    }

    //The already paid amount for a P2P Payment channel given a nonce
    mapping(bytes32 => mapping(bytes32 => uint256)) noncePaidAmount;

    //The P2P Payment channel Id for a User channel number
    mapping(address => mapping(uint256 => bytes32)) userChannels;

    //The P2P channel for a channel Id
    mapping(bytes32 => Channel) channels;

    //The number of a User total number of channels
    mapping(address => uint256) numberOfUserChannels;

    // Notifies that a new Channel was opened
    event ChannelOpened(
        bytes32 id,
        address indexed sender,
        address indexed recipient,
        uint256 amount
    );

    // Notifies for a deposit to a Channel
    event DepositToChannel(bytes32 id, address indexed sender, uint256 amount);

    // Notifies for Channel closed
    event ChannelClosed(bytes32 id, address indexed sender, uint256 amount);

    // Notifies for Off-chain transaction finalized
    event P2POffChainTransaction(
        bytes32 indexed channelId,
        address indexed sender,
        address indexed recipient,
        uint256 recipientAmount
    );

    //Open a new P2P Payment channel
    //The first Peer(Channel Owner) is the Tx signer address
    //The secord Peer is the recipient address
    //The locked amount is the coins transfered to smart contract (msg.sender)
    //Locks the coins for the lockTimeInDays days from now
    function openChannel(address payable recipient, uint256 lockTimeInDays)
        public
        payable
    {
        //Amount to be locked should be greater than zero
        require(msg.value > 0);

        //The 2 Peers should be different addresses
        require(recipient != msg.sender);

        Channel memory newChannel;

        //Channel Id by hashing the 2 peers and now timestamp
        newChannel.id = keccak256(abi.encodePacked(msg.sender, recipient, now));

        //Check if there is an already an opened channel for the recipient that has been mined previously on the same Block
        require(!channels[newChannel.id].isOpen, "Channel Id already exists.");

        //Store the Channel Id on Owner's number of opened channels. Initially 0
        userChannels[msg.sender][numberOfUserChannels[msg.sender]] = newChannel
            .id;

        //Increase the number of Owner number of opened channels by 1
        numberOfUserChannels[msg.sender] += 1;

        //Setup the number of locked Coins, the Peers and lock until Timestamp
        newChannel.balance = msg.value;
        newChannel.sender = msg.sender;
        newChannel.recipient = recipient;
        newChannel.isOpen = true;
        newChannel.lockUntil = now + lockTimeInDays * 1 days;

        //Setup the channel on storage
        channels[newChannel.id] = newChannel;

        //Notify for the channel creation
        emit ChannelOpened(newChannel.id, msg.sender, recipient, msg.value);
    }

    //Increase the number of locked coins for a Channel Id, extend the lock until Timestamp by increaseLckTimeInDays days
    function depositToChannel(bytes32 id, uint256 increaseLckTimeInDays)
        public
        payable
    {
        //Extra Amount should be greater than zero
        require(msg.value > 0);

        //Channel Owner should be the Tx signer
        require(
            channels[id].sender == msg.sender,
            "Message signer isn't the owner of channel"
        );

        //The extend number of days should be greater than zero
        require(increaseLckTimeInDays >= 0);

        //The Channel should be in Open State
        require(channels[id].isOpen);

        //Setup the new locked amount balance and lock until Timestamp
        channels[id].balance += msg.value;
        channels[id].lockUntil =
            channels[id].lockUntil +
            increaseLckTimeInDays *
            1 days;

        //Notify for the Deposit on an existing Channel
        emit DepositToChannel(id, msg.sender, msg.value);
    }

    //Closes a Channel by releasing the remaining locked coins to Owner
    function closeChannel(bytes32 id) public {
        //Check that locked coins balance is grater than zero
        require(channels[id].balance > 0, "Insufficient balance");

        //Channel Owner should be the Tx signer
        require(
            channels[id].sender == msg.sender,
            "Message signer isn't the owner of channel"
        );

        //The lock until period should be in the past
        require(channels[id].lockUntil < now, "Balance is locked");

        //Calculate and transfer the remaining balance to Owner address, Reset the balance, Close the Channel
        uint256 amount = channels[id].balance;
        channels[id].balance = 0;
        channels[id].isOpen = false;
        msg.sender.transfer(amount);

        //Notify for the channel termination
        emit ChannelClosed(id, msg.sender, amount);
    }

    //Settle a P2P Offchain Transaction
    // h is the hash of signature
    // r and s are outputs of the ECDSA signature
    // v is the recovery id
    // channelId is the P2P Channel Id
    // The P2P nonce for the Channel Id
    // The amount to be released from locked to recipient address
    function finalizeOffchainP2PTransaction(
        bytes32 h,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 channelId,
        bytes32 nonce,
        uint256 amount
    ) public {
        //Calculate hash of input arguments channelId, nonce and amount
        bytes32 proof = keccak256(abi.encodePacked(channelId, nonce, amount));

        //The hash of input arguments should be equal with provided Offcain transaction Hash(Parameter h)
        require(
            proof == h,
            "Off-chain transaction hash does't match with payload"
        );

        //Recover the Offcain transaction Signer using ECDA public key Recovery
        address signer = ecrecover(h, v, r, s);

        //Signer of the Tx should be the Owner of P2P Channel
        require(
            signer == channels[channelId].sender,
            "Signer should be the channel Owner"
        );

        //Check the the requested amount is greater than any previously paid for the same nonce
        require(
            noncePaidAmount[channelId][nonce] < amount,
            "Requested amount should be greater than the previous finalized for P2P content transaction"
        );

        //The delta betwwen the requested amount minus any previously paid for the same nonce(This is the amount will be transfer to recipient address)
        uint256 amountToBeTransferred = amount -
            noncePaidAmount[channelId][nonce];

        //Setup the already paid amount for the channel given a nonce
        noncePaidAmount[channelId][nonce] = amount;

        //Check the existing Channel balance is sufficient
        require(
            channels[channelId].balance >= amountToBeTransferred,
            "Insufficient balance"
        );

        //Reduce the existing Channel balance
        channels[channelId].balance -= amountToBeTransferred;

        //Transfer the Coins to recipient
        address payable channelRecipient = channels[channelId].recipient;
        channelRecipient.transfer(amountToBeTransferred);

        //Notify for Offchain Tx settlement
        emit P2POffChainTransaction(
            channelId,
            signer,
            channelRecipient,
            amountToBeTransferred
        );
    }

    //Return the Channel Id by a given Peer Channel number
    function getChannelId(uint256 userChannelId) public view returns (bytes32) {
        return userChannels[msg.sender][userChannelId];
    }

    //Return the total number of Channels of a Peer
    function getUserTotalChannels() public view returns (uint256) {
        return numberOfUserChannels[msg.sender];
    }

    //The Relayer Payment Channel structure
    struct Relayer {
        //Relayer name
        string name;
        //Relayer Owner address
        address payable owner;
        //Relayer Offchain Endpoint URL that expose the Relayer API
        string domain;
        //Max allowed number of Peers(Depositors) based on requested Relayer license
        uint256 maxUsers;
        //Max allowed number of Coins(Deposits) based on requested Relayer license
        uint256 maxCoins;
        //Max allowed Offcain transactions throughput based on requested Relayer license
        uint256 maxTxThroughput;
        //Current number of Peers(Depositors)
        uint256 currentUsers;
        //Current deposited Coins
        uint256 currentCoins;
        //Current used Offcain transactions throughput
        uint256 currentTxThroughput;
        //Delay of expected Offchain transaction settlement in number of Blocks
        uint256 offchainTxDelay;
        //Relayer fee(Thousands percent)
        uint256 fee;
        //Remaining Releayer penalty funds
        uint256 remainingPenaltyFunds;
    }

    //Total Releayers for Epoch
    mapping(uint256 => uint256) public relayersCounter;

    //Relayer for epoch and Index
    mapping(uint256 => mapping(uint256 => Relayer)) public relayers;

    //The index of a Relayer for Epoch and Relayer Owner address. Index starts from value of 1
    mapping(uint256 => mapping(address => uint256)) public epochRelayerIndex;

    // Notify for a new Relayer as candidate
    event RelayerProposed(
        uint256 indexed epoch,
        address indexed relayer,
        string domain,
        address indexed owner,
        string name,
        uint256 fee,
        uint256 offchainTxDelay
    );

    // Notify for Relayer updated
    event RelayerUpdated(
        uint256 indexed epoch,
        address indexed relayer,
        string domain,
        string name,
        uint256 fee,
        uint256 offchainTxDelay
    );

    // Notify for Relayer withdrawal of penalty funds
    event RelayerWithdrawFunds(
        uint256 indexed epoch,
        address indexed relayer,
        uint256 amount
    );

    //Called by a Relayer that requests a new license for an upcoming Epoch
    //targetEpoch is the requested Epoch, usually Current Epoch + 1
    //domain is the Relayer Offchain Endpoint URL that expose the Relayer API
    //name is Relayer name
    //fee is the Relayer fee(Thousands percent)
    //maxUsers is the requested max number of Peers(Depositors)
    //maxCoins is the requested max Coins could be deposited by Peers(Total Deposits)
    //maxTxThroughput is the requested max allowed Offcain transactions throughput per 100000 Blocks
    //offchainTxDelay is the expected settlement delay in Blocks
    function requestRelayerLicense(
        uint256 targetEpoch,
        string memory domain,
        string memory name,
        uint256 fee,
        uint256 maxUsers,
        uint256 maxCoins,
        uint256 maxTxThroughput,
        uint256 offchainTxDelay
    ) public payable {
        //If the requested isn't the initial Epoch(0)
        //Check that election is open
        //Check that requested is upcoming
        if (targetEpoch > 1) {
            require(
                block.number < getCurrentRelayersElectionEnd(),
                "Relayers election period has passed"
            );
            require(
                targetEpoch > getCurrentEpoch(),
                "Target epoch should be greater than current"
            );
        }

        //Check for the validity of provided input parameters
        require(maxUsers > 0, "maxUsers should be greater than 0");
        require(maxCoins > 0, "maxCoins should be greater than 0");
        require(
            maxTxThroughput > 0,
            "maxTxThroughput should be greater than 0"
        );
        require(
            offchainTxDelay > 0,
            "offchainTxDelay should be greater than 0"
        );
        require(fee < 1000, "Fee should be lower than 1000");

        //Calculate the Coins required for lock by Relayer based on requested license
        uint256 requiredAmount = getFundRequiredForRelayer(
            maxUsers,
            maxCoins,
            maxTxThroughput
        );

        //Check that at least the Coins required are transfered to be locked
        require(requiredAmount <= msg.value, "Invalid required amount");

        //Check that there isn't any existing Relayer(Owner) license request for the requested Epoch
        require(
            epochRelayerIndex[targetEpoch][msg.sender] == 0,
            "Already registered Relayer as candidate"
        );

        //Get the number of licenses requested for the Epoch
        uint256 currentRelayersNumber = relayersCounter[targetEpoch];

        //If current number of licenses exceeds the max allowed number lookup for a Relayer to be replaced
        //Else place the requestor on list
        if (currentRelayersNumber >= maximumRelayersNumber) {
            address payable toBeReplacedRelayer = address(0);
            uint256 toBeReplacedRelayerIndex = 0;
            for (uint256 i = 1; i <= currentRelayersNumber; i++) {
                //1st Relayer with lower funds is choosed to be replaced
                if (
                    relayers[targetEpoch][i].remainingPenaltyFunds < msg.value
                ) {
                    toBeReplacedRelayer = address(
                        uint160(relayers[targetEpoch][i].owner)
                    );
                    toBeReplacedRelayerIndex = i;
                    break;
                }
            }

            //If no Relayer found to be replaced Revert Transaction
            if (toBeReplacedRelayer == address(0)) {
                revert("Relayers list is full");
            }

            //Else the Replace the found Relayer with the requestor and transfer the locked funds back to his address
            uint256 refund = relayers[targetEpoch][toBeReplacedRelayerIndex]
                .remainingPenaltyFunds;
            epochRelayerIndex[targetEpoch][toBeReplacedRelayer] = 0;
            relayers[targetEpoch][toBeReplacedRelayerIndex].fee = fee;
            relayers[targetEpoch][toBeReplacedRelayerIndex].maxUsers = maxUsers;
            relayers[targetEpoch][toBeReplacedRelayerIndex].maxCoins = maxCoins;
            relayers[targetEpoch][toBeReplacedRelayerIndex]
                .maxTxThroughput = maxTxThroughput;
            relayers[targetEpoch][toBeReplacedRelayerIndex]
                .offchainTxDelay = offchainTxDelay;
            relayers[targetEpoch][toBeReplacedRelayerIndex]
                .remainingPenaltyFunds = requiredAmount;
            relayers[targetEpoch][toBeReplacedRelayerIndex].name = name;
            relayers[targetEpoch][toBeReplacedRelayerIndex].domain = domain;
            relayers[targetEpoch][toBeReplacedRelayerIndex].owner = msg.sender;
            epochRelayerIndex[targetEpoch][msg
                .sender] = toBeReplacedRelayerIndex;
            toBeReplacedRelayer.transfer(refund);
        } else {
            relayersCounter[targetEpoch]++;
            relayers[targetEpoch][relayersCounter[targetEpoch]].fee = fee;
            relayers[targetEpoch][relayersCounter[targetEpoch]]
                .maxUsers = maxUsers;
            relayers[targetEpoch][relayersCounter[targetEpoch]]
                .maxCoins = maxCoins;
            relayers[targetEpoch][relayersCounter[targetEpoch]]
                .maxTxThroughput = maxTxThroughput;
            relayers[targetEpoch][relayersCounter[targetEpoch]]
                .offchainTxDelay = offchainTxDelay;
            relayers[targetEpoch][relayersCounter[targetEpoch]]
                .remainingPenaltyFunds = requiredAmount;
            relayers[targetEpoch][relayersCounter[targetEpoch]].name = name;
            relayers[targetEpoch][relayersCounter[targetEpoch]].domain = domain;
            relayers[targetEpoch][relayersCounter[targetEpoch]].owner = msg
                .sender;
            epochRelayerIndex[targetEpoch][msg
                .sender] = relayersCounter[targetEpoch];
        }

        //Notify for License request
        emit RelayerProposed(
            targetEpoch,
            msg.sender,
            domain,
            msg.sender,
            name,
            fee,
            offchainTxDelay
        );
    }

    function testHashing(bytes32 id, string memory domain)
        public
        pure
        returns (
            bool,
            bytes32,
            bytes32
        )
    {
        bytes32 lid = keccak256(abi.encodePacked(domain));
        return (lid == id, id, lid);
    }

    //Update domain, name, fees, expected Tx daley for the requested Epoch of an existing Relayer
    function updateRelayer(
        uint256 targetEpoch,
        string memory domain,
        string memory name,
        uint256 fee,
        uint256 offchainTxDelay
    ) public {
        uint256 index = epochRelayerIndex[targetEpoch][msg.sender];

        //Check that Relayer is in list
        require(index > 0, "Relayer not found");

        //Check other input parameters
        require(fee < 1000, "Fee should be lower than 1000");
        require(
            offchainTxDelay > 0,
            "offchainTxDelay should be greater than 0"
        );

        //Setup new properties
        relayers[targetEpoch][index].domain = domain;
        relayers[targetEpoch][index].name = name;
        relayers[targetEpoch][index].fee = fee;
        relayers[targetEpoch][index].offchainTxDelay = offchainTxDelay;

        //Notify Relayer updated
        emit RelayerUpdated(
            targetEpoch,
            msg.sender,
            domain,
            name,
            fee,
            offchainTxDelay
        );
    }

    //Withdraw Relayer locked funds for a previous Epoch
    function relayerWithdrawPenaltyFunds(uint256 targetEpoch) public {
        uint256 index = epochRelayerIndex[targetEpoch][msg.sender];

        //Check that Relayer is in list
        require(index > 0, "Relayer not found");

        uint256 currentEpoch = getCurrentEpoch();
        //Requested Epoch should be less than Previous Epoch
        require(
            targetEpoch < currentEpoch - 1,
            "Current epoch should be lower than requested epoch"
        );

        //Transfer the remaining funds to Relayer Owner address
        uint256 remainingAmount = relayers[targetEpoch][index]
            .remainingPenaltyFunds;
        require(remainingAmount > 0, "Insufficient balance");

        relayers[targetEpoch][index].remainingPenaltyFunds = 0;

        msg.sender.transfer(remainingAmount);

        //Notify for Relayer withdrawal
        emit RelayerWithdrawFunds(targetEpoch, msg.sender, remainingAmount);
    }

    //User Relayer Deposit structure
    struct DepositOnRelayer {
        //Lock funds until Block
        uint256 lockUntilBlock;
        //The remaining user balance
        uint256 balance;
    }

    //Deposit of a User
    mapping(address => mapping(address => DepositOnRelayer))
        public userDepositOnRelayer;

    //Amount settled for a user to beneficiary Offchain payment given a nonce and a Relayer
    mapping(address => mapping(address => mapping(address => mapping(bytes32 => uint256))))
        public userToBeneficiaryFinalizedAmountForNonce;

    //Notify for user deposit on Relayer
    event UserDeposit(
        address indexed relayer,
        address indexed user,
        uint256 amount
    );

    //Notify for user withdraw on Relayer
    event UserWithdraw(
        address indexed relayer,
        address indexed user,
        uint256 amount
    );

    //Notify for Off-chain transaction finalized
    event RelayedOffChainTransaction(
        address indexed relayer,
        address indexed user,
        address indexed beneficiary,
        uint256 relayerFee,
        uint256 beneficiaryAmount,
        bool isPayedFromPenaltyFunds
    );

    //Deposit to a Relayer
    //relayerId is the Relayer Owner address
    //lockUntilBlock is the Block number that funds are locked
    function depositToRelayer(address relayerId, uint256 lockUntilBlock)
        public
        payable
    {
        uint256 targetEpoch = getCurrentEpoch();
        uint256 index = epochRelayerIndex[targetEpoch][relayerId];
        //Check that Relayer is in list
        require(index > 0, "Relayer not found");

        //Check that Relayer has remaiining funds(Is active), Deposit amount grater than zero, lock until Block is greater than current Block
        require(
            relayers[targetEpoch][index].remainingPenaltyFunds > 0,
            "Relayer doesn't have any remaining penalty funds"
        );
        require(msg.value > 0, "Deposit amount should be greater then 0");
        require(
            lockUntilBlock > block.number,
            "The lockTimeInDays should be greater than zero"
        );

        //If 1st deposit on Relayer increase the numner of Relayer current users
        if (userDepositOnRelayer[msg.sender][relayerId].lockUntilBlock == 0) {
            relayers[targetEpoch][index].currentUsers += 1;
        } else {
            //Check that new lock until value is greater or equal than existing
            require(
                userDepositOnRelayer[msg.sender][relayerId].lockUntilBlock >=
                    lockUntilBlock,
                "The lockTimeInDays should be greater than any previous lock until Block"
            );
        }

        userDepositOnRelayer[msg.sender][relayerId]
            .lockUntilBlock = lockUntilBlock;

        //Check if current Relayer users exceeds the Relayer license
        require(
            relayers[targetEpoch][index].currentUsers <=
                relayers[targetEpoch][index].maxUsers,
            "Max users limit violated"
        );

        //Add coins to total Relayer Deposits
        relayers[targetEpoch][index].currentCoins += msg.value;

        //Check if total Relayer Deposits exceeds tha Relayer license
        require(
            relayers[targetEpoch][index].currentCoins <=
                relayers[targetEpoch][index].maxCoins,
            "Max coins limit violated"
        );

        //Add Tx amount to User balance
        userDepositOnRelayer[msg.sender][relayerId].balance += msg.value;

        //Notify for Deposit
        emit UserDeposit(relayerId, msg.sender, msg.value);
    }

    //User withdraw funds from Relayer
    function withdrawFunds(address relayerId, uint256 amount) public {
        //Check if balance is still locked
        require(
            userDepositOnRelayer[msg.sender][relayerId].lockUntilBlock <
                block.number,
            "Balance locked"
        );

        //Check if balance is greater than requested amount
        require(
            userDepositOnRelayer[msg.sender][relayerId].balance >= amount,
            "Insufficient balance"
        );

        //Remove requested amount from User balance
        userDepositOnRelayer[msg.sender][relayerId].balance -= amount;

        //Transfer money to User address
        msg.sender.transfer(amount);

        //Notifu for Withdrawal
        emit UserWithdraw(relayerId, msg.sender, amount);
    }

    //Return the User as Signer of Offchain Tx checking that input parameters are valid
    // h is the hash of signature
    // r and s are outputs of the ECDSA signature
    // v is the recovery id
    // nonce is The P2P Tx unique identifier
    // fee is the Relayer fee
    // beneficiary is the Beneficiary address
    // amount is the amount to be transfered
    function checkOffchainSignature(
        bytes32 h,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 nonce,
        uint256 fee,
        address payable beneficiary,
        uint256 amount
    ) public pure returns (address signer) {
        //Calculate hash of input arguments beneficiary, nonce and amount
        bytes32 proof = keccak256(
            abi.encodePacked(beneficiary, nonce, amount, fee)
        );

        //The hash of input arguments should be equal with provided Offcain transaction Hash(Parameter h)
        require(
            proof == h,
            "Off-chain transaction hash does't match with payload"
        );

        //Recover the Offcain transaction Signer using ECDA public key Recovery(User that signed the Tx)
        signer = ecrecover(h, v, r, s);

        return signer;
    }

    //Return the Relayer as Signer of Offchain Tx checking that input parameters are valid
    // proof is the Hash of User generated Offchain Payment
    // rh is the hash of signature
    // rr and rs are outputs of the ECDSA signature
    // rv is the recovery id
    // txUntilBlock is the Block number that Relayer should proceed with the Tx Onchain. Otherwise should be penaltized with the amount reducing Relayer ramining funds
    function checkOffchainRelayerSignature(
        bytes32 proof,
        bytes32 rh,
        uint8 rv,
        bytes32 rr,
        bytes32 rs,
        uint256 txUntilBlock
    ) public pure returns (address payable relayerid) {
        //Calculate hash of input arguments txUntilBlock and proof
        bytes32 relayerProof = keccak256(abi.encodePacked(proof, txUntilBlock));

        //The hash of input arguments should be equal with provided Offcain transaction Hash(Parameter rh)
        require(
            relayerProof == rh,
            "Off-chain transaction hash does't match with payload"
        );

        //Recover the Offcain transaction Signer using ECDA public key Recovery(Relayer that signed the Tx)
        address relayer = ecrecover(rh, rv, rr, rs);
        relayerid = address(uint160((relayer)));
        return relayerid;
    }

    //Calculate the fund required to be locked by a Relayer when requesting a new license
    //maxUsers is the requested max number of Peers(Depositors)
    //maxCoins is the requested max Coins could be deposited by Peers(Total Deposits)
    //maxTxThroughputPer100000Blocks is the requested max allowed Offcain transactions throughput per 100000 Blocks
    function getFundRequiredForRelayer(
        uint256 maxUsers,
        uint256 maxCoins,
        uint256 maxTxThroughputPer100000Blocks
    ) public pure returns (uint256 requiredAmount) {
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
                        requiredAmount += maxUsers.mulByFraction(
                            125 * 1 ether,
                            10
                        );
                    } else {
                        requiredAmount += 1000000 * (125 / 10) * 1 ether;
                        maxUsers -= 1000000;
                        requiredAmount += maxUsers.mul(10 * 1 ether);
                    }
                }
            }
        }

        if (maxCoins <= 1000 * 1 ether) {
            requiredAmount += maxCoins.mulByFraction(500, 1000);
        } else {
            requiredAmount += (1000 * 500) / 1000;
            maxCoins -= 1000 * 1 ether;
            if (maxCoins <= 10000 * 1 ether) {
                requiredAmount += maxCoins.mulByFraction(200, 1000);
            } else {
                requiredAmount += (10000 * 200) / 1000;
                maxCoins -= 10000 * 1 ether;
                if (maxCoins <= 100000 * 1 ether) {
                    requiredAmount += maxCoins.mulByFraction(100, 1000);
                } else {
                    requiredAmount += (100000 * 100) / 1000;
                    maxCoins -= 100000 * 1 ether;
                    if (maxCoins <= 1000000 * 1 ether) {
                        requiredAmount += maxCoins.mulByFraction(10, 1000);
                    } else {
                        requiredAmount += (1000000 * 10) / 1000;
                        maxCoins -= 1000000 * 1 ether;
                        requiredAmount += maxCoins.mulByFraction(1, 1000);
                    }
                }
            }
        }

        if (maxTxThroughputPer100000Blocks <= 10) {
            requiredAmount += maxTxThroughputPer100000Blocks.mulByFraction(
                10000 * 1 ether,
                100000
            );
        } else {
            requiredAmount += (10 * 10000 * 1 ether) / 100000;
            maxTxThroughputPer100000Blocks -= 10;
            if (maxTxThroughputPer100000Blocks <= 1000) {
                requiredAmount += maxTxThroughputPer100000Blocks.mulByFraction(
                    120000 * 1 ether,
                    100000
                );
            } else {
                requiredAmount += (1000 * 120000 * 1 ether) / 100000;
                maxTxThroughputPer100000Blocks -= 1000;
                if (maxTxThroughputPer100000Blocks <= 100000) {
                    requiredAmount += maxTxThroughputPer100000Blocks
                        .mulByFraction(150000 * 1 ether, 100000);
                } else {
                    requiredAmount += (100000 * 150000 * 1 ether) / 100000;
                    maxTxThroughputPer100000Blocks -= 100000;
                    if (maxTxThroughputPer100000Blocks <= 10000000) {
                        requiredAmount += maxTxThroughputPer100000Blocks
                            .mulByFraction(200000 * 1 ether, 100000);
                    } else {
                        requiredAmount +=
                            (10000000 * 200000 * 1 ether) /
                            100000;
                        maxTxThroughputPer100000Blocks -= 10000000;
                        requiredAmount += maxTxThroughputPer100000Blocks
                            .mulByFraction(1000000 * 1 ether, 100000);
                    }
                }
            }
        }
    }

    //Settle a P2P Offchain Transaction through a Relayer that has signed the Tx
    // h is the hash of P2P signature
    // r and s are outputs of the ECDSA P2P signature
    // v is the recovery id of P2P signature
    // rh is the hash of Relayer signature
    // rr and rs are outputs of the ECDSA Relayer signature
    // rv is the recovery id of Relayer signature
    // nonce is The P2P Tx unique identifier
    // fee is the Relayer fee
    // txUntilBlock is the Block number that Relayer should proceed with the Tx Onchain
    // the Beneficiary address
    // The amount to be tranfered from locked initiator(P2P Tx Siginer) amount to beneficiary
    function finalizeOffchainRelayerTransaction(
        bytes32 h,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 rh,
        uint8 rv,
        bytes32 rr,
        bytes32 rs,
        bytes32 nonce,
        uint256 fee,
        uint256 txUntilBlock,
        address payable beneficiary,
        uint256 amount
    ) public {
        //Check and get P2P Signer
        address signer = checkOffchainSignature(
            h,
            v,
            r,
            s,
            nonce,
            fee,
            beneficiary,
            amount
        );

        //Check and get Relayer
        address payable relayerId = checkOffchainRelayerSignature(
            h,
            rh,
            rv,
            rr,
            rs,
            txUntilBlock
        );

        //Get the Epoch of the txUntilBlock
        uint256 epoch = getEpochByBlock(txUntilBlock);

        //Get the Relayer of above Epoch
        uint256 index = epochRelayerIndex[epoch][relayerId];

        //If Relayer not found and not the Initial Epoch try get the Relayer of the previous Epoch
        if (index == 0 && epoch > 1) {
            epoch = epoch - 1;
            index = epochRelayerIndex[epoch][relayerId];
        }

        //Check that Relayer finally found
        require(index > 0, "Relayer not found");

        //Check the requested amount is greater than the previously used of the same nonce
        require(
            userToBeneficiaryFinalizedAmountForNonce[signer][beneficiary][relayerId][nonce] <
                amount,
            "Requested amount should be greater than the previous finalized for withdraw request or P2P content transaction"
        );

        //Get the delta between requested and the previously used of the same nonce
        uint256 amountToBeTransferred = amount -
            userToBeneficiaryFinalizedAmountForNonce[signer][beneficiary][relayerId][nonce];

        //Set amount as the last used of the same nonce
        userToBeneficiaryFinalizedAmountForNonce[signer][beneficiary][relayerId][nonce] = amount;

        uint256 relayerFee = 0;
        bool isPayedFromPenaltyFunds = false;

        //Find if the P2P user or Relayer should pay in case of delayed Tx
        if (txUntilBlock >= block.number) {
            //Check that P2P Signer has the required balance on Relayer
            require(
                userDepositOnRelayer[signer][relayerId].balance >=
                    amountToBeTransferred,
                "Insufficient balance"
            );
            userDepositOnRelayer[signer][relayerId]
                .balance -= amountToBeTransferred;
            relayerFee = amountToBeTransferred.mulByFraction(fee, 1000);
        } else {
            isPayedFromPenaltyFunds = true;
            relayers[epoch][index]
                .remainingPenaltyFunds -= amountToBeTransferred;
        }

        //Transfer the money to Beneficiary address
        beneficiary.transfer(amountToBeTransferred - relayerFee);

        //If there is a fee transfer to Relayer Owner address
        if (relayerFee > 0) {
            relayerId.transfer(relayerFee);
        }

        //Notity for Settlement
        emit RelayedOffChainTransaction(
            relayerId,
            signer,
            beneficiary,
            relayerFee,
            amountToBeTransferred,
            isPayedFromPenaltyFunds
        );
    }
}
