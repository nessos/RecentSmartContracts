/* 
RE-Cent Validators Smart Contract v.1.0.0
Author: Giannis Zarifis <jzarifis@gmail.com>
*/

pragma solidity ^0.5.0;

import "./RecentBlockchain.sol";

//This Smart Contract used by providing the Validators on each Epoch. ALso implements the Validators election mechanism by Witnesses and Service providers
//Inherits from RecentBlockchain base Contract 
contract RecentValidators is RecentBlockchain {
	

	constructor(address[] memory initial) public
	{
		systemAddress = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;
		for (uint i = 0; i < initial.length; i++) {
			status[1][initial[i]].isIn = true;
			status[1][initial[i]].index = i;
		}
		validators[1] = initial;
	}

	//System address allowed to call reward method
	address public systemAddress;

	//Notify for Validators list changed
	event ChangeFinalized(address[] currentSet);

	//Validators change request finalized
	bool public finalized;

	// Structure of Validator status and Index in list 
	struct AddressStatus {
		bool isIn;
		uint index;
	}

	// Notify for maliciuos behaviour of a Validator
	event Report(address indexed reporter, address indexed reported, bool indexed malicious);

	//Accept reports for Validator when Report Block > Current Block - recentBlocks
	uint public recentBlocks = 20;

	// Current list of addresses entitled to participate in the consensus(Active Validators)
	mapping(uint=> address[]) public validators;
	//mapping(uint=> address[]) public pending;

	//List of Candidates of an Epoch
	mapping(uint=> address[]) public candidates;

	//The current status of a Validator for an Epoch
	mapping(uint=>mapping(address  => AddressStatus)) public status;

	//Total staking funds of a Validator for an Epoch including Witnesses and Service Providers staking funds
	mapping(uint=> mapping(address=> uint256)) public validatorTotalStakingFunds;

	//Validator staking funds for an Epoch
	mapping(uint=> mapping(address=> uint256)) public validatorStakingFunds;

	//Reward for Witnesses locked from a Validator for an  Epoch
	mapping(uint=> mapping(address=> uint256)) public validatorWitnessesFunds;

	//Free service provided by Service Providers for a Validator and Epoch
	mapping(uint=> mapping(address=> uint256)) public validatorFreeMbs;

	//Total Witnesses staking funds for a Validator and Epoch
	mapping(uint=> mapping(address=> uint256)) public validatorTotalWitnessesFunds;

	//Funds locked by a Witness for and Validator and Epoch
	mapping(uint=> mapping(address=> mapping(address=> uint256))) public witnessStakingFundsForValidator;

	//Funds locked by a Service Provider for and Validator and Epoch
	mapping(uint=> mapping(address=> mapping(address=> uint256))) public freeServiceProvidersFundsForValidator;

	//Free service in Mb provided by Service Provider for a Validator and Epoch
	mapping(uint=> mapping(address=> mapping(address=> uint256))) public freeServiceProvidersFreeMbs;

	//List of Validator Witnesses for an EPoch
	mapping(uint=> mapping(address => address[])) public validatorWitnesses;

	//List of Validator Service Providers for an Epoch
	mapping(uint=> mapping(address => address[])) public validatorFreeServiceProviders;


	//Is Validator when Status isIn and in List and Validator address match with addrees in list
	modifier isValidator(address addr) {
		uint epoch = getCurrentEpoch();
		// bool isIn = status[epoch][addr].isIn;
		// uint index = status[epoch][addr].index;

		require(status[epoch][addr].isIn && status[epoch][addr].index < validators[epoch].length && validators[epoch][status[epoch][addr].index] == addr);
		_;
	}

	//Not a Validator when not in list
	modifier isNotValidator(address addr) {
		uint epoch = getCurrentEpoch();
		require(!status[epoch][addr].isIn);
		_;
	}

	//Caller is system address
	modifier onlySystem() {
		require(msg.sender == systemAddress);
		_;
	}

	//Is recent Block number
	modifier isRecent(uint blockNumber) {
		require(block.number <= blockNumber + recentBlocks && blockNumber < block.number);
		_;
	}

	modifier whenFinalized() {
		require(finalized);
		_;
	}

	modifier whenNotFinalized() {
		require(!finalized);
		_;
	}

	

	//Notify for Validator addtition 
	event ValidatorAdded(uint indexed epoch, address indexed validator);

	//Notify for Validator removal
	event ValidatorRemoved(uint indexed epoch, address indexed validator);

	//Notity for Validator proposal
	event ValidatorProposed(uint indexed epoch, address indexed validator, uint256 stakingFunds, uint256 witnessesFunds );

	//Notify for Validator voted by a Witness
	event ValidatorVotedByWitness(uint indexed epoch, address indexed validator, address indexed witness, uint256 amount);

	//Motify for Validator voted by a Service Pro
	event ValidatorVotedByServiceProvider(uint indexed epoch, address indexed validator, address indexed serviceProvider, uint256 amount);

	//Return the list of active Validators for an EPoch
	function getCandidates(uint epoch)
		public
		view
		returns (address[] memory)
	{
		return candidates[epoch];
	}

	//Return the list of Service Providers voted for a Validator and Epoch
	function getValidatorFreeServiceProviders(uint epoch, address candidate)
		public
		view
		returns (address[] memory)
	{
		return validatorFreeServiceProviders[epoch][candidate];
	}

	//Return the list of Witnesses voted for a Validator and Epoch
	function getValidatorWitnesses(uint epoch, address candidate)
		public
		view
		returns (address[] memory)
	{
		return validatorWitnesses[epoch][candidate];
	}

	//Validator proposed
	function validatorVoted(uint epoch, uint256 amount, address validator, uint256 freeMbs) private {
		//If new Candidate then push in list
		if (validatorTotalStakingFunds[epoch][validator] == 0) {
			candidates[epoch].push(validator);
		}

		//Add the amount to total staking funds
		validatorTotalStakingFunds[epoch][validator] += amount;

		//Add freeMbs to total free Mbs
		validatorFreeMbs[epoch][validator] += freeMbs;

		//If not in list or in list but inactive
		if (!status[epoch][validator].isIn) {
			// if length of validators < max allowed number
			if (validators[epoch].length < maximumValidatorsNumber) {
				//Add to Validators list
				validators[epoch].push(validator);

				//Setup the status
				status[epoch][validator].isIn = true;
				status[epoch][validator].index = validators[epoch].length;
			} else {
				//Iterate to find any validator with lower total staking funds
				for (uint i=0; i < validators[epoch].length; i++) {
					address existingValidator = validators[epoch][i];

					//If found replace with proposed
					if (status[epoch][existingValidator].isIn && validatorTotalStakingFunds[epoch][existingValidator] < validatorTotalStakingFunds[epoch][msg.sender])	{
						status[epoch][existingValidator].isIn = false;
						status[epoch][validator].isIn = true;
						status[epoch][validator].index = i;
						validators[epoch][i] = msg.sender;
						emit ValidatorRemoved(epoch, existingValidator);
						break;
					}
				}
			}

			//If propose results to Validator addition to list then notify
			if (status[epoch][validator].isIn)	{
				emit ValidatorAdded(epoch, validator);
			}
		}

	}

	//Calculate the required staking funds for a Candidate
	function getRequiredStakingFunds(uint epoch) public view returns (uint256) {
		return epochBlocks.mulByFraction(calculateReward(epoch),maximumValidatorsNumber);
	}

	//Benign percent penalty
	mapping (uint=>uint) public benignPercent;

	//Block reward for an Epoch
	mapping (uint=>uint256) public epochReward;

	//Request as Candidate
	//stakingFunds is the amount required to be allocated for staking
	//witnessesFunds is the amount provided to Witnesses
	function validatorAsCandidate(uint256 stakingFunds, uint256 witnessesFunds) public payable {
		//Target Epoch is the next Epoch
		uint epoch = getCurrentEpoch() + 1;

		//Check the Tx amount equals to stakingFunds + witnessesFunds
		require(stakingFunds + witnessesFunds == msg.value, "Transfered amount should be equal to stakingFunds + witnessesFunds");

		//Check that election is still open
		require(block.number < getCurrentValidatorsElectionEnd(), "Relayers election period has passed");

		//Check that required staking funds equals with provided
		uint256 requiredStaking = getRequiredStakingFunds(epoch);
		require(requiredStaking == stakingFunds, "Insufficient stakingFunds");

		//Calculate reword for target Epoch and penalty on Benign behavior
		epochReward[epoch] = calculateReward(epoch);
		benignPercent[epoch] =  epochReward[epoch].mul(100).div(requiredStaking);
		
		//Setup staking funds and funds for Witnesses
		validatorStakingFunds[epoch][msg.sender] += stakingFunds;
		validatorWitnessesFunds[epoch][msg.sender] += witnessesFunds;

		//Try to add Candidate to Validators list for the target Epoch
		validatorVoted(epoch, msg.value, msg.sender, 0);

		//Notify for the new Candidate
		emit ValidatorProposed(epoch, msg.sender, stakingFunds, witnessesFunds);
	}

	//The penalty percent for Witnesses in case of Validator benign behavior
	mapping (uint => mapping (address=>uint)) public benignPercentPenaltyForWitnesses;

	//Witness vote a Candidate
	//validator is the Candidate
	function voteValidatorAsWitness(address payable validator) public payable {
		//Target Epoch is the next Epoch
		uint epoch = getCurrentEpoch() + 1;

		//Check that election is still open
		require(block.number < getCurrentValidatorsElectionEnd(), "Relayers election period has passed");

		//Check that Candidate exists
		require(validatorStakingFunds[epoch][validator] > 0, "Validator not found");

		//The Witness staking amount should be greater then the Witness wallet balance * witnessRequiredBalancePercent %
		require(msg.sender.balance.mulByFraction(witnessRequiredBalancePercent,100) <= msg.value, "Invalid Witness balance. Should be less than witnessRequiredBalancePercent");

		//If a new Witness for Candidate add to list of Candidate Witnesses
		if (witnessStakingFundsForValidator[epoch][msg.sender][validator] == 0) {
			validatorWitnesses[epoch][validator].push(msg.sender);
		}

		//Setup the total staking funds for the Candidate and target Epoch
		witnessStakingFundsForValidator[epoch][msg.sender][validator] += msg.value;

		//Setup total Witnesses staking funds for the Candidate and target Epoch
		validatorTotalWitnessesFunds[epoch][validator] += msg.value;

		//Calculate the penalty for Witnesses when Validator has benign behavior
		benignPercentPenaltyForWitnesses[epoch][validator] = validatorTotalWitnessesFunds[epoch][validator].mulByFraction(benignPercent[epoch],100);

		//Try to add Candidate to Validators list for the target Epoch
		validatorVoted(epoch, msg.value, validator, 0);

		//Notify for Witness vote
		emit ValidatorVotedByWitness(epoch, validator, msg.sender, msg.value);
	}


	//Service provider vote for a Candidate
	function voteValidatorAsServiceProvider(address payable validator, uint freeContentInMb) public payable {
		//Target Epoch is the next Epoch
		uint epoch = getCurrentEpoch() + 1;

		//Check that election is still open
		require(block.number < getCurrentValidatorsElectionEnd(), "Relayers election period has passed");

		//Check that Candidate exists
		require(validatorStakingFunds[epoch][validator] > 0, "Validator not found");

		//Check that free content provided * price per Mb equals Tx amount
		require(freeContentInMb.mul(pricePerMb) == msg.value, "Transfered amount should be freeContentInMb * pricePerMb");

		//If a new Service provider for Candidate add to list of Candidate Service providers
		if (freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] == 0) {
			validatorFreeServiceProviders[epoch][validator].push(msg.sender);
		}

		//Setup the total staking funds for the Candidate and target Epoch
		freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] += msg.value;
		//Setup the free content for the Candidate and target Epoch
		freeServiceProvidersFreeMbs[epoch][msg.sender][validator] += freeContentInMb;
		//Try to add Candidate to Validators list for the target Epoch
		validatorVoted(epoch, msg.value, validator, freeContentInMb);

		//Notify for Service provider vote
		emit ValidatorVotedByServiceProvider(epoch, validator, msg.sender, msg.value);
	}

	//Funs paid to Witnesses per Epoch, Witness, Validator
	mapping(uint=> mapping(address=> mapping(address=> uint256))) public validatorWitnessPaidAmount;

	//Notify for Witness payment from Validator witnessesFunds
	event WitnessPaid(uint indexed epoch, address indexed witness, address indexed validator, uint256 amount);


	//Request payment from a Validator witnessesFunds for an Epoch
	function witnessPaymentRequest(uint epoch, address validator) public {
		uint currentEpoch = getCurrentEpoch();

		//Requested Epoch should be <= Current Epoch
		require(currentEpoch >= epoch , "Current epoch should be greater or equal than the requested");

		//Check that Witness exists in Witnesses list for the Validator
		require(witnessStakingFundsForValidator[epoch][msg.sender][validator] > 0, "Not a valid witness");

		//Check that Witness is unpaid
		require(validatorWitnessPaidAmount[epoch][msg.sender][validator] == 0, "Already paid");

		//Check that Validator is in list of Validators for requested Epoch
		require(status[epoch][validator].isIn, "Validator not found");

		//Calculate the amount to be paid to Witness proportional to his staking amount
		uint256 amount = validatorWitnessesFunds[epoch][validator].mulByFraction(witnessStakingFundsForValidator[epoch][msg.sender][validator],validatorTotalWitnessesFunds[epoch][validator]);

		//Setup the amount paid from Validator to Witness
		validatorWitnessPaidAmount[epoch][msg.sender][validator] = amount;

		//Tranfer to Witness address
		msg.sender.transfer(amount);

		//Notify for payment
		emit WitnessPaid(epoch, msg.sender, validator, amount);	
	}

	//Notify for Witness withdrawal
	event WitnessRefunded(uint indexed epoch, address indexed witness, address indexed validator, uint256 amount);

	//Witness withdraw request for reamining funds 
	function witnessWithdrawRequest(uint epoch, address validator) public {
		uint currentEpoch = getCurrentEpoch();

		//Check that there are remaining funds
		require(witnessStakingFundsForValidator[epoch][msg.sender][validator] > 0, "No remaining funds");

		//Requested Epoch should be in the past
		require(currentEpoch  > epoch, "Current epoch should be greater than requested");

		//Calculate the Validator remaining funds percent against the initial staking amount
		uint percentAvailable = (100 - penaltyPercent[epoch][validator]);

		//Calculate the amount for withdraw as remaining Witness staking funds * percentAvailable %
		uint256 amount = witnessStakingFundsForValidator[epoch][msg.sender][validator].mulByFraction(percentAvailable, 100);

		//Reset the reamining Witness staking funds
		witnessStakingFundsForValidator[epoch][msg.sender][validator] = 0;

		//Transfer to Witness address
		msg.sender.transfer(amount);

		//Notify for withdrawal
		emit WitnessRefunded(epoch, msg.sender, validator, amount);	
	}

	//Notify for Validator withdrwal
	event ValidatorRefunded(uint indexed epoch, address indexed validator, uint256 amount);

	//Validator request for any remaining staking funds
	function validatorWithdrawRequest(uint epoch) public {
		uint currentEpoch = getCurrentEpoch();

		//Check that there are remaining funds
		require(validatorStakingFunds[epoch][msg.sender]> 0, "No remaining funds");

		//Requested Epoch should be in the past
		require(currentEpoch  > epoch, "Current epoch should be greater than requested ");

		//Get, reset and transfer the remaining amount
		uint256 amount = validatorStakingFunds[epoch][msg.sender];
		validatorStakingFunds[epoch][msg.sender] = 0;
		msg.sender.transfer(amount);

		//Notify for Withdrawal
		emit ValidatorRefunded(epoch, msg.sender, amount);	
	}

	//Notify for Service provider withdrawal
	event FreeServiceProviderRefunded(uint indexed epoch, address indexed witness, address indexed validator, uint256 amount);

	//Service provider request for any remaining staking funds
	function freeServiceProviderWithdrawRequest(uint epoch, address validator) public {
		uint currentEpoch = getCurrentEpoch();

		//Check that there are remaining funds
		require(freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] > 0, "No remaining funds");

		//Requested Epoch should be in the past
		require(currentEpoch  > epoch, "Current epoch should be greater than requested ");

		//Get, reset and transfer the remaining amount
		uint256 amount = freeServiceProvidersFundsForValidator[epoch][msg.sender][validator];
		freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] = 0;
		msg.sender.transfer(amount);

		//Notify for Withdrawal
		emit FreeServiceProviderRefunded(epoch, msg.sender, validator, amount);	
	}

	//Below mappings are used for disputes when a service provider hasn't provided the free content promised to Witnesses
	//Claimed amount for a Peer per Epoch, Validator and Serive provider
	mapping(uint=> mapping(address=> mapping(address => mapping(address => uint256)))) public freeMbClaimedPerValidatorFreeserviceProviderWitness; 

	//Free Mb Disputed by Witness per per Epoch, Validator and Serive provider
	mapping(uint=> mapping(address=> mapping(address => mapping(address => bool)))) public freeMbDisputedPerValidatorFreeserviceProviderWitness;

	//The dispute end period in Block number
	mapping(uint=> mapping(address=> mapping(address => mapping(address => uint)))) public freeMbDisputedEndsPerValidatorFreeserviceProviderWitness;

	//Dispute canceled due to proof of free service provided by Service provider
	mapping(uint=> mapping(address=> mapping(address => mapping(address => bool)))) public freeMbDisputedCanceledDueProofGivenPerValidatorFreeserviceProviderWitness;

	//Notify for Dispute
	event FreeServiceProviderFreeMbDisputed(uint indexed epoch, address indexed witness, address indexed validator, address freeServiceProvider, uint256 freeMb);

	//Initiate a dispute request from a Witness against a Service provider for a Validator and Epoch
	//freeMb is the free Mbs disputed by Witness
	function startDispute(uint epoch, address validator, address freeServiceProvider, uint256 freeMb) public {
		uint currentEpoch = getCurrentEpoch();

		//Traget epoch should be the current or in the past
		require(currentEpoch >= epoch, "Current epoch should be greater or equal than requested");

		//Check that isn't claimed in the past
		require(freeMbClaimedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender]==0, "Already claimed");

		//Check that there isn't any active Dispute
		require(!freeMbDisputedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender], "Already disputed");
		
		//Check that Validator was in list of Validators
		require(status[epoch][validator].isIn, "Not a validator");

		//Check that requestor was a Witness
		require(witnessStakingFundsForValidator[epoch][msg.sender][validator] > 0, "Not a witness for validator");

		//Check that Service provider exists in list of Validator service providers
		require(freeServiceProvidersFundsForValidator[epoch][freeServiceProvider][validator] > 0, "Not a free service provider for validator");

		//Calculate the freeMb to be disputed based on total available free service in Mbs / number of Validator Witnesses
		uint freeMbAvailablePerWitness = freeServiceProvidersFreeMbs[epoch][freeServiceProvider][validator].div(validatorWitnesses[epoch][validator].length);

		//Check freeMb to be disputed should be equal with the requested
		require(freeMbAvailablePerWitness == freeMb, "Invalid freeMb");

		//Setup dispute
		freeMbDisputedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender] = true;

		//Setup end of dispute in Blocks
		freeMbDisputedEndsPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender] = block.number + freeServiceDisputeThreshold;

		//Notify for Dispute
		emit FreeServiceProviderFreeMbDisputed(epoch, msg.sender, validator, freeServiceProvider, freeMb);	
	}

	//Notify for Dispute settlement
	event FreeServiceProviderFreeMbDisputeFinished(uint indexed epoch, address indexed witness, address indexed validator, address freeServiceProvider, uint256 amount);

	//Request for Dispute amount settlment
	function requestDisputedFunds(uint epoch, address validator, address freeServiceProvider) public {

		//Check that isn't claimed in the past
		require(freeMbClaimedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender]==0, "Already claimed");

		//Check that there is an open Dispute
		require(freeMbDisputedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender], "Not disputed");

		//Unable to settle as Service provider canceled the Dispute providing a proof for free service
		require(!freeMbDisputedCanceledDueProofGivenPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender], "Unable to refund, proof provided");

		//Dispute is still open waing for Service provider proof
		require(freeMbDisputedEndsPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender] < block.number, "Request disputed funds not currently available");		
		
		//Calculate the freeMb to be disputed based on total available free service in Mbs / number of Validator Witnesses
		uint freeMbAvailablePerWitness = freeServiceProvidersFreeMbs[epoch][freeServiceProvider][validator].div(validatorWitnesses[epoch][validator].length);

		//Calculate the amount to be Paid to Witness 
		uint amount = freeMbAvailablePerWitness.mul(pricePerMb);		
		//Should not happen. Insufficient remaining funds
		require(freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] >= amount, "No remaining funds");

		//Setup and transfer the amount
		freeMbClaimedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender] = amount;
		msg.sender.transfer(amount);

		//Notity that Witness won the Dispute and paid
		emit FreeServiceProviderFreeMbDisputeFinished(epoch, msg.sender, validator, freeServiceProvider, amount);	
	}

	//Check and return the Signer(Witness) of a free service proof  
	// h is the hash of P2P signature
	// r and s are outputs of the ECDSA P2P signature
	// v is the recovery id of P2P signature
	// epoch is Offchain transaction Epoch
	// freeServiceProvider is the Service provider
	// validator is the Witness Validator
	// freeMb the the Mb provided for free
	function checkFreeServiceProof(
		bytes32 h,
		uint8   v,
		bytes32 r,
		bytes32 s,
		uint epoch,
		address freeServiceProvider,
		address validator,
		uint256 freeMb) public pure returns (address signer)
	{
		//Calculate hash of input arguments freeServiceProvider,validator,epoch and freeMb 
		bytes32 proof = keccak256(abi.encodePacked( freeServiceProvider, validator, epoch, freeMb));

		//Check that proof equals requested hash
		require(proof == h, "Off-chain transaction hash does't match with payload");

 		//Recover the Offcain transaction Signer using ECDA public key Recovery(Service provider that signed the Tx)
		signer = ecrecover(h, v, r, s);

		return signer;
	}

	//Notify that a Service provider cancleled a Dispute by providing a proof of free content
	event FreeServiceProviderFreeMbDisputeCanceled(uint indexed epoch, address indexed witness, address indexed validator, address freeServiceProvider, uint256 freeMb);

	//Cancel a Dispute request by providing proof of free content
	function cancelDisputeByProvideProof(
		bytes32 h,
		uint8   v,
		bytes32 r,
		bytes32 s,
		uint epoch,
		address freeServiceProvider,
		address validator,
		uint256 freeMb) public
	{

		//Get the signer(Witness) by checking the proof validity
		address witness = checkFreeServiceProof(h, v, r, s, epoch, freeServiceProvider, validator, freeMb );

		//Dispute period has passed
		require(freeMbDisputedEndsPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][witness] >= block.number, "Cancelation not allowed");
		
		//There is no active dispute
		require(freeMbDisputedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][witness], "Not disputed");
		
		//Already canceled by previous proof
		require(!freeMbDisputedCanceledDueProofGivenPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][witness], "Proof already provided");
		
		//Calculate the freeMb to be disputed based on total available free service in Mbs / number of Validator Witnesses
		uint freeMbAvailablePerWitness = freeServiceProvidersFreeMbs[epoch][freeServiceProvider][validator].div(validatorWitnesses[epoch][validator].length);
		
		//Check freeMb in Dispute disputed should be equal with the requested(via proof)
		require(freeMbAvailablePerWitness == freeMb, "Invalid freeMb");

		//Setup cancelation
		freeMbDisputedCanceledDueProofGivenPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][witness] = true;
		
		//Notify for cancelation
		emit FreeServiceProviderFreeMbDisputeCanceled(epoch, msg.sender, validator, freeServiceProvider, freeMb);   
	}

	// OWNER FUNCTIONS

	// // Add a validator.
	// function addValidator(address _validator)
	// 	external
	// 	onlyOwner
	// 	isNotValidator(_validator)
	// {
	// 	status[_validator].isIn = true;
	// 	status[_validator].index = pending.length;
	// 	pending.push(_validator);
	// 	triggerChange();
	// }

	// // Remove a validator.
	// function removeValidator(address _validator)
	// 	external
	// 	onlyOwner
	// 	isValidator(_validator)
	// {
	// 	// Remove validator from pending by moving the
	// 	// last element to its slot
	// 	uint index = status[_validator].index;
	// 	pending[index] = pending[pending.length - 1];
	// 	status[pending[index]].index = index;
	// 	delete pending[pending.length - 1];
	// 	pending.length--;

	// 	// Reset address status
	// 	delete status[_validator];

	// 	triggerChange();
	// }


	// Called to determine the current set of validators.
	function getValidatorsByEpoch(uint epoch)
		public
		view
		returns (address[] memory)
	{
		if (validators[epoch].length==0) {
			return validators[1];
		} else {
			return validators[epoch];
		}	
		
	}

	//Get the current Epoch set of Validators
	function getValidators()
		public
		view
		returns (address[] memory)
	{
		return getValidatorsByEpoch(getCurrentEpoch());
	}

	//Total number of Validators for Epoch
	function getValidatorsNumber(uint epoch)
		public
		view
		returns (uint validatorsNumber)
	{
		return getValidatorsByEpoch(epoch).length;
	}

	// // Called to determine the pending set of validators.
	// function getPending()
	// 	external
	// 	view
	// 	returns (address[] memory)
	// {
	// 	return pending;
	// }

	// INTERNAL

	//Setbits of benign behaviour per Validator and Epoch
	mapping (uint=>mapping(address=>uint256)) benignReportedByblockNumber;

	//Setbits of malicious behaviour per Validator and Epoch
	mapping (uint=>mapping(address=>uint256)) maliciousReportedByblockNumber;


	//Get the number of Setbits that has value of true 
	function getNumberOfSetBits(uint256 n) public pure returns (uint result){
        uint256 count = 0; 
        while (n > 0) 
        { 
            count += n & 1; 
            n >>= 1; 
        } 
        return count; 
    }

	//The penalty percent for benign behaviour
	mapping (uint=>mapping(address=>uint)) penaltyPercent;


	//Notify that a Validator is replaced
	event ValidatorReplaced(uint indexed epoch, address indexed oldValidator, address indexed newValidator);

	//Replace Validator request by a Candiate that has more staking funds
	function replaceValidator(address validator) public
			isValidator(validator)
	{
			uint epoch = getCurrentEpoch();
			//Check that requestor Candidate has more available funds than the requested
			require(validatorStakingFunds[epoch][msg.sender] > validatorStakingFunds[epoch][validator],"Cannot be replaced");
			
			//Requestor is already in Vaidators list
			require(!status[epoch][msg.sender].isIn,"Already a validator");

			//Replace
			validators[epoch][status[epoch][validator].index] = msg.sender;
			status[epoch][validator].isIn = false;
			status[epoch][msg.sender].isIn = true;
			status[epoch][msg.sender].index = status[epoch][validator].index;

			//Notify
			emit ValidatorReplaced(epoch, validator, msg.sender);
	}


	// Report that a validator has misbehaved in a benign way.
	function reportBenign(address validator, uint blockNumber)
		public
		isValidator(msg.sender)
		isValidator(validator)
		isRecent(blockNumber)
	{
		uint epoch = getCurrentEpoch();
		
		//Remaining funds is zero, cannot add penalty
		if (validatorStakingFunds[epoch][validator] == 0 )
		{
			return;
		}


		uint totalValidatorsNumber = validators[epoch].length;

		//Setup Setbits
		benignReportedByblockNumber[blockNumber][validator] = benignReportedByblockNumber[blockNumber][validator] | (2 ** status[epoch][msg.sender].index);
		
		//Get the total number of benign reports for Block and Validator
		uint setBits = getNumberOfSetBits(benignReportedByblockNumber[blockNumber][validator]);

		//If the number of unique reporters is over 50% of total validators
		if (setBits >= totalValidatorsNumber.mulByFraction(50,100)) {
			
			//Reset Setbits
			benignReportedByblockNumber[blockNumber][validator] = 0;
			
			// Epoch block reward
			uint256 penalty = epochReward[epoch];
			
			//Add benign percent to the total penalties applied to Validator
			penaltyPercent[epoch][validator] += benignPercent[epoch];

			//If penalty is greater than remaining funds get the remaining
			if (validatorStakingFunds[epoch][validator] < penalty) {
				penalty = validatorStakingFunds[epoch][validator] ;
			}
			
			//Reduce the remaining funds by penalty
			validatorStakingFunds[epoch][validator] -= penalty;
			
			//Reduce total staking funds by penalty
			validatorTotalStakingFunds[epoch][validator] -= penalty;

			//Find and reduce the Witnesses panalty
			uint256 penaltyFromWitnesses = benignPercentPenaltyForWitnesses[epoch][validator];
			validatorTotalStakingFunds[epoch][validator] -= penaltyFromWitnesses;
			validatorTotalWitnessesFunds[epoch][validator] -= penaltyFromWitnesses;

			//Share per Validator
			uint256 penaltyShare = (penalty + penaltyFromWitnesses).mulByFraction(1, totalValidatorsNumber - 1);
			if (penaltyShare> 0) {
				
				for (uint i=0; i < validators[epoch].length; i++) {
					if (validators[epoch][i] != validator) {
						address(uint160(validators[epoch][i])).transfer(penaltyShare);
					}
					
				}
			}
			 
		}
		
		emit Report(msg.sender, validator, false);
	}

	//Proofs per Validator, Reporter and Block	
	mapping (address => mapping (address => mapping(uint=>bytes))) proofs;

	// Report that a validator has misbehaved maliciously.
	function reportMalicious(
		address validator,
		uint blockNumber,
		bytes memory proof
	)
		public
		isValidator(msg.sender)
		isValidator(validator)
		isRecent(blockNumber)
	{		
		uint epoch = getCurrentEpoch();
		//Not enough staking funds, return
		if (validatorStakingFunds[epoch][validator] == 0 )
		{
			return;
		}


		uint totalValidatorsNumber = validators[epoch].length;

		//Setup Setbits
		maliciousReportedByblockNumber[blockNumber][validator] = maliciousReportedByblockNumber[blockNumber][validator] | (2 ** status[epoch][msg.sender].index);
		
		//Get the total number of malicious behaviour reports for Block and Validator
		uint setBits = getNumberOfSetBits(maliciousReportedByblockNumber[blockNumber][validator]);

		//If the number of unique reporters is over 50% of total validators
		if (setBits >= totalValidatorsNumber.mulByFraction(50,100)) {

			//Reset Setbits
			maliciousReportedByblockNumber[blockNumber][validator] = 0;

			//Penalty is the whole remaining amount
			uint256 penalty = validatorStakingFunds[epoch][validator];			
			penaltyPercent[epoch][validator] = 100;

			//There aren't any remaining funds
			validatorStakingFunds[epoch][validator] = 0;
			validatorTotalStakingFunds[epoch][validator] -= penalty;

			//All the remaing Witnesses funds are reset to zero
			uint256 penaltyFromWitnesses = validatorTotalWitnessesFunds[epoch][validator] ;
			validatorTotalStakingFunds[epoch][validator] -= penaltyFromWitnesses;
			validatorTotalWitnessesFunds[epoch][validator] = 0;

			//Share the penalties to Validators
			uint256 penaltyShare = (penalty + penaltyFromWitnesses).mulByFraction(1, totalValidatorsNumber - 1);
			if (penaltyShare > 0) {			
				for (uint i=0; i < validators[epoch].length; i++) {
					if (validators[epoch][i] != validator) {
						address(uint160(validators[epoch][i])).transfer(penaltyShare);
					}
					
				}
			}
			 
		}
		
		//Setup proof
		proofs[msg.sender][validator][blockNumber] = proof;

		//Notify
		emit Report(msg.sender, validator, true);
	}

	// Called when an initiated change reaches finality and is activated.
	function finalizeChange()
		public
		onlySystem
		whenNotFinalized
	{
		finalized = true;
		uint epoch = getCurrentEpoch();
		emit ChangeFinalized(validators[epoch]);
	}

	// PRIVATE

	// function triggerChange()
	// 	private
	// 	whenFinalized
	// {
	// 	finalized = false;
	// }

	//Notify for init Validator set
	event InitiateChange(bytes32 indexed _parentHash, address[] _newSet);

	function initiateChange(bytes32 parentHash, address[] memory newSet)
		public	
	{
		emit InitiateChange(parentHash, newSet);
	}

	//Last block that contained rewards for miners
	uint lastClaimedIssuanceBlock;

	// produce rewards for the given benefactors, with corresponding reward codes.
	// only callable by `SYSTEM_ADDRESS`
	function reward(address[] calldata benefactors, uint16[] calldata kind) external view onlySystem returns (address[] memory, uint256[] memory) {
		require(benefactors.length == kind.length);
		//Calculate the reward
		uint256 calculateRewardValue = calculateReward(block.number, lastClaimedIssuanceBlock);
		uint256[] memory rewards = new uint256[](benefactors.length);

		//Iterate and produce Reward only for Miners
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

