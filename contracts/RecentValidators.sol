 /* 
RE-Cent Validators Smart Contract v.1.0.0
Author: Giannis Zarifis <jzarifis@gmail.com>


*/

pragma solidity ^0.5.0;

import "./RecentBlockchain.sol";


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

	address public systemAddress;

	event ChangeFinalized(address[] currentSet);


	bool public finalized;

	// TYPES
	struct AddressStatus {
		bool isIn;
		uint index;
	}

	// EVENTS
	event Report(address indexed reporter, address indexed reported, bool indexed malicious);

	// STATE
	uint public recentBlocks = 20;

	// Current list of addresses entitled to participate in the consensus.
	mapping(uint=> address[]) public validators;
	//mapping(uint=> address[]) public pending;

	mapping(uint=> address[]) public candidates;

	mapping(uint=>mapping(address  => AddressStatus)) public status;

	mapping(uint=> mapping(address=> uint256)) public validatorTotalStakingFunds;

	mapping(uint=> mapping(address=> uint256)) public validatorStakingFunds;

	mapping(uint=> mapping(address=> uint256)) public validatorWitnessesFunds;


	mapping(uint=> mapping(address=> uint256)) public validatorFreeMbs;

	mapping(uint=> mapping(address=> uint256)) public validatorTotalWitnessesFunds;

	mapping(uint=> mapping(address=> mapping(address=> uint256))) public witnessStakingFundsForValidator;

	mapping(uint=> mapping(address=> mapping(address=> uint256))) public freeServiceProvidersFundsForValidator;

	mapping(uint=> mapping(address=> mapping(address=> uint256))) public freeServiceProvidersFreeMbs;

	mapping(uint=> mapping(address => address[])) public validatorWitnesses;

	mapping(uint=> mapping(address => address[])) public validatorFreeServiceProviders;



	modifier isValidator(address addr) {
		uint epoch = getCurrentEpoch();
		// bool isIn = status[epoch][addr].isIn;
		// uint index = status[epoch][addr].index;

		require(status[epoch][addr].isIn && status[epoch][addr].index < validators[epoch].length && validators[epoch][status[epoch][addr].index] == addr);
		_;
	}

	modifier isNotValidator(address addr) {
		uint epoch = getCurrentEpoch();
		require(!status[epoch][addr].isIn);
		_;
	}

	modifier onlySystem() {
		require(msg.sender == systemAddress);
		_;
	}

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

	


	event ValidatorAdded(uint indexed epoch, address indexed validator);

	event ValidatorRemoved(uint indexed epoch, address indexed validator);

	event ValidatorProposed(uint indexed epoch, address indexed validator, uint256 stakingFunds, uint256 witnessesFunds );

	event ValidatorVotedByWitness(uint indexed epoch, address indexed validator, address indexed witness, uint256 amount);

	event ValidatorVotedByServiceProvider(uint indexed epoch, address indexed validator, address indexed serviceProvider, uint256 amount);


	function getCandidates(uint epoch)
		public
		view
		returns (address[] memory)
	{
		return candidates[epoch];
	}

	function getValidatorFreeServiceProviders(uint epoch, address candidate)
		public
		view
		returns (address[] memory)
	{
		return validatorFreeServiceProviders[epoch][candidate];
	}

	function getValidatorWitnesses(uint epoch, address candidate)
		public
		view
		returns (address[] memory)
	{
		return validatorWitnesses[epoch][candidate];
	}

	function validatorVoted(uint epoch, uint256 amount, address validator, uint256 freeMbs) private {
		if (validatorTotalStakingFunds[epoch][validator] == 0) {
			candidates[epoch].push(validator);
		}
		validatorTotalStakingFunds[epoch][validator] += amount;
		validatorFreeMbs[epoch][validator] += freeMbs;
		if (!status[epoch][validator].isIn) {
			if (validators[epoch].length < maximumValidatorsNumber) {
				validators[epoch].push(validator);
				status[epoch][validator].isIn = true;
				status[epoch][validator].index = validators[epoch].length;
			}
			for (uint i=0; i < validators[epoch].length; i++) {
				address existingValidator = validators[epoch][i];
				if (status[epoch][existingValidator].isIn && validatorTotalStakingFunds[epoch][existingValidator] < validatorTotalStakingFunds[epoch][msg.sender])	{
					status[epoch][existingValidator].isIn = false;
					status[epoch][validator].isIn = true;
					status[epoch][validator].index = i;
					validators[epoch][i] = msg.sender;
					emit ValidatorRemoved(epoch, existingValidator);
					break;
				}
			}
			
			if (status[epoch][validator].isIn)	{
				emit ValidatorAdded(epoch, validator);
			}
		}

	}


	function getRequiredStakingFunds(uint epoch) public view returns (uint256) {
		return epochBlocks.mulByFraction(calculateReward(epoch),maximumValidatorsNumber);
	}

	function validatorAsCandidate(uint256 stakingFunds, uint256 witnessesFunds) public payable {
		uint epoch = getCurrentEpoch() + 1;
		require(stakingFunds + witnessesFunds == msg.value, "Transfered amount should be equal to stakingFunds + witnessesFunds");
		require(block.number < getCurrentValidatorsElectionEnd(), "Relayers election period has passed");
		require( getRequiredStakingFunds(epoch)<= stakingFunds, "Insufficient stakingFunds");

		validatorStakingFunds[epoch][msg.sender] += stakingFunds;
		validatorWitnessesFunds[epoch][msg.sender] += witnessesFunds;
		validatorVoted(epoch, msg.value, msg.sender, 0);
		emit ValidatorProposed(epoch, msg.sender, stakingFunds, witnessesFunds);
	}

	function voteValidatorAsWitness(address payable validator) public payable {
		uint epoch = getCurrentEpoch() + 1;
		require(block.number < getCurrentValidatorsElectionEnd(), "Relayers election period has passed");
		require(validatorStakingFunds[epoch][validator] > 0, "Validator not found");
		require(msg.sender.balance.mulByFraction(witnessRequiredBalancePercent,100) <= msg.value, "Invalid address balance");
		if (witnessStakingFundsForValidator[epoch][msg.sender][validator] == 0) {
			validatorWitnesses[epoch][validator].push(msg.sender);
		}
		witnessStakingFundsForValidator[epoch][msg.sender][validator] += msg.value;
		validatorTotalWitnessesFunds[epoch][validator] += msg.value;
		validatorVoted(epoch, msg.value, validator, 0);
		emit ValidatorVotedByWitness(epoch, validator, msg.sender, msg.value);
	}

	function voteValidatorAsServiceProvider(address payable validator, uint freeContentInMb) public payable {
		uint epoch = getCurrentEpoch() + 1;
		require(block.number < getCurrentValidatorsElectionEnd(), "Relayers election period has passed");
		require(validatorStakingFunds[epoch][validator] > 0, "Validator not found");
		require(freeContentInMb.mul(pricePerMb) == msg.value, "Transfered amount should be freeContentInMb * pricePerMb");
		if (freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] == 0) {
			validatorFreeServiceProviders[epoch][validator].push(msg.sender);
		}
		freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] += msg.value;
		freeServiceProvidersFreeMbs[epoch][msg.sender][validator] += freeContentInMb;

		validatorVoted(epoch, msg.value, validator, freeContentInMb);
		emit ValidatorVotedByServiceProvider(epoch, validator, msg.sender, msg.value);
	}


	mapping(uint=> mapping(address=> mapping(address=> uint256))) public validatorWitnessPaidAmount;

	event WitnessPaid(uint indexed epoch, address indexed witness, address indexed validator, uint256 amount);



	function witnessPaymentRequest(uint epoch, address validator) public {
		uint currentEpoch = getCurrentEpoch();
		require(currentEpoch  > epoch , "Current epoch should be greater than requested");
		require(witnessStakingFundsForValidator[epoch][msg.sender][validator] > 0, "Not a valid witness");
		require(validatorWitnessPaidAmount[epoch][msg.sender][validator] == 0, "Already paid");
		require(status[epoch][validator].isIn, "Validator not found");

		uint256 amount = validatorWitnessesFunds[epoch][validator].mulByFraction(witnessStakingFundsForValidator[epoch][msg.sender][validator],validatorTotalWitnessesFunds[epoch][validator]);
		validatorWitnessPaidAmount[epoch][msg.sender][validator] = amount;
		msg.sender.transfer(amount);
		emit WitnessPaid(epoch, msg.sender, validator, amount);	
	}


	event WitnessRefunded(uint indexed epoch, address indexed witness, address indexed validator, uint256 amount);

	function witnessWithdrawRequest(uint epoch, address validator) public {
		uint currentEpoch = getCurrentEpoch();
		require(witnessStakingFundsForValidator[epoch][msg.sender][validator] > 0, "No remaining funds");
		if (status[epoch][validator].isIn) {
			require(currentEpoch  > epoch + 1, "Current epoch should be greater than requested + 1");
		} else {
			require(currentEpoch  > epoch + 1, "Current epoch should be greater than requested");
		}
		uint256 amount = witnessStakingFundsForValidator[epoch][msg.sender][validator];
		witnessStakingFundsForValidator[epoch][msg.sender][validator] = 0;
		msg.sender.transfer(amount);
		emit WitnessRefunded(epoch, msg.sender, validator, amount);	
	}

	event ValidatorRefunded(uint indexed epoch, address indexed validator, uint256 amount);

	function validatorWithdrawRequest(uint epoch) public {
		uint currentEpoch = getCurrentEpoch();
		require(validatorStakingFunds[epoch][msg.sender]> 0, "No remaining funds");
		if (status[epoch][msg.sender].isIn) {
			require(currentEpoch  > epoch + 1, "Current epoch should be greater than requested + 1");
		} else {
			require(currentEpoch  > epoch + 1, "Current epoch should be greater than requested");
		}
		uint256 amount = validatorStakingFunds[epoch][msg.sender];
		validatorStakingFunds[epoch][msg.sender] = 0;
		msg.sender.transfer(amount);
		emit ValidatorRefunded(epoch, msg.sender, amount);	
	}


	event FreeServiceProviderRefunded(uint indexed epoch, address indexed witness, address indexed validator, uint256 amount);

	function freeServiceProviderWithdrawRequest(uint epoch, address validator) public {
		uint currentEpoch = getCurrentEpoch();
		require(freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] > 0, "No remaining funds");
		if (status[epoch][validator].isIn) {
			require(currentEpoch  > epoch + 1, "Current epoch should be greater than requested + 1");
		} else {
			require(currentEpoch  > epoch + 1, "Current epoch should be greater than requested");
		}
		uint256 amount = freeServiceProvidersFundsForValidator[epoch][msg.sender][validator];
		freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] = 0;
		msg.sender.transfer(amount);
		emit FreeServiceProviderRefunded(epoch, msg.sender, validator, amount);	
	}

	mapping(uint=> mapping(address=> mapping(address => mapping(address => uint256)))) public freeMbClaimedPerValidatorFreeserviceProviderWitness; 
	mapping(uint=> mapping(address=> mapping(address => mapping(address => bool)))) public freeMbDisputedPerValidatorFreeserviceProviderWitness;
	mapping(uint=> mapping(address=> mapping(address => mapping(address => uint)))) public freeMbDisputedEndsPerValidatorFreeserviceProviderWitness;
	mapping(uint=> mapping(address=> mapping(address => mapping(address => bool)))) public freeMbDisputedCanceledDueProofGivenPerValidatorFreeserviceProviderWitness;

	event FreeServiceProviderFreeMbDisputed(uint indexed epoch, address indexed witness, address indexed validator, address freeServiceProvider, uint256 freeMb);

	function startDispute(uint epoch, address validator, address freeServiceProvider, uint256 freeMb) public {
		uint currentEpoch = getCurrentEpoch();
		require(currentEpoch  >= epoch, "Current epoch should be greater or equal than requested");
		require(freeMbClaimedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender]==0, "Already claimed");
		require(!freeMbDisputedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender], "Already disputed");
		
		require(status[epoch][validator].isIn, "Not a validator");
		require(witnessStakingFundsForValidator[epoch][msg.sender][validator] > 0, "Not a witness for validator");
		require(freeServiceProvidersFundsForValidator[epoch][freeServiceProvider][validator] > 0, "Not a free service provider for validator");
		uint freeMbAvailablePerWitness = freeServiceProvidersFreeMbs[epoch][freeServiceProvider][validator].div(validatorWitnesses[epoch][validator].length);
		require(freeMbAvailablePerWitness == freeMb, "Invalid freeMb");
		freeMbDisputedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender] = true;
		freeMbDisputedEndsPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender] = block.number + freeServiceDisputeThreshold;
		emit FreeServiceProviderFreeMbDisputed(epoch, msg.sender, validator, freeServiceProvider, freeMb);	
	}

	event FreeServiceProviderFreeMbDisputeFinished(uint indexed epoch, address indexed witness, address indexed validator, address freeServiceProvider, uint256 amount);

	function requestDisputedFunds(uint epoch, address validator, address freeServiceProvider) public {
		require(freeMbClaimedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender]==0, "Already claimed");
		require(freeMbDisputedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender], "Not disputed");
		require(!freeMbDisputedCanceledDueProofGivenPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender], "Unable to refund, proof provided");
		require(freeMbDisputedEndsPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender] < block.number, "Request disputed funds not currently available");		
		uint freeMbAvailablePerWitness = freeServiceProvidersFreeMbs[epoch][freeServiceProvider][validator].div(validatorWitnesses[epoch][validator].length);
		uint amount = freeMbAvailablePerWitness.mul(pricePerMb);		
		//Should not happen
		require(freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] >= amount, "No remaining funds");

		freeMbClaimedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender] = amount;
		msg.sender.transfer(amount);
		emit FreeServiceProviderFreeMbDisputeFinished(epoch, msg.sender, validator, freeServiceProvider, amount);	
	}


	function checkFreeServiceProof(
		bytes32 h,
		uint8   v,
		bytes32 r,
		bytes32 s,
		uint epoch,
		address beneficiary,
		address validator,
		uint256 freeMb) public pure returns (address signer)
	{
		bytes32 proof = keccak256(abi.encodePacked( beneficiary, validator, epoch, freeMb));
		require(proof == h, "Off-chain transaction hash does't match with payload");
		signer = ecrecover(h, v, r, s);

		return signer;
	}

	event FreeServiceProviderFreeMbDisputeCanceled(uint indexed epoch, address indexed witness, address indexed validator, address freeServiceProvider, uint256 freeMb);

	function cancelDisputeByProvideProof(
		bytes32 h,
		uint8   v,
		bytes32 r,
		bytes32 s,
		uint epoch,
		address beneficiary,
		address validator,
		uint256 freeMb) public
	{

		
		address freeServiceProvider = checkFreeServiceProof(h, v, r, s, epoch, beneficiary, validator, freeMb );

		require(freeMbDisputedEndsPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender] >= block.number, "Cancelation not allowed");
		require(freeMbDisputedPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender], "Not disputed");
		require(!freeMbDisputedCanceledDueProofGivenPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender], "Proof already provided");
		uint freeMbAvailablePerWitness = freeServiceProvidersFreeMbs[epoch][freeServiceProvider][validator].div(validatorWitnesses[epoch][validator].length);
		require(freeMbAvailablePerWitness == freeMb, "Invalid freeMb");

		freeMbDisputedCanceledDueProofGivenPerValidatorFreeserviceProviderWitness[epoch][validator][freeServiceProvider][msg.sender] = true;
		
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

	function getValidators()
		public
		view
		returns (address[] memory)
	{
		return getValidatorsByEpoch(getCurrentEpoch());
	}

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


	mapping (uint=>mapping(address=>uint256)) benignReportedByblockNumber;
	mapping (uint=>mapping(address=>uint256)) maliciousReportedByblockNumber;


	function getNumberOfSetBits(uint256 n) public pure returns (uint result){
        uint256 count = 0; 
        while (n > 0) 
        { 
            count += n & 1; 
            n >>= 1; 
        } 
        return count; 
    }

	event ValidatorReplaced(uint indexed epoch, address indexed oldValidator, address indexed newValidator);

	function replaceValidator(address validator) public
			isValidator(validator)
	{
			uint epoch = getCurrentEpoch();
			require(validatorStakingFunds[epoch][validator] ==0,"Validator cannot be replaced");
			require(validatorStakingFunds[epoch][msg.sender] > 0,"Request not from valid candidate");
			require(!status[epoch][msg.sender].isIn,"Already a validator");

			validators[epoch][status[epoch][validator].index] = msg.sender;
			status[epoch][validator].isIn = false;
			status[epoch][msg.sender].isIn = true;
			status[epoch][msg.sender].index = status[epoch][validator].index;
			uint totalValidatorsNumber = validators[epoch].length;
			uint256 penaltyShare = validatorTotalWitnessesFunds[epoch][validator].mulByFraction(1,totalValidatorsNumber - 1);
			if (penaltyShare > 0) {
				for (uint i=0; i < validatorWitnesses[epoch][validator].length; i++) {
					witnessStakingFundsForValidator[epoch][validatorWitnesses[epoch][validator][i]][validator] = 0;
					validatorTotalWitnessesFunds[epoch][validator]=0;					
				}

				for (uint i=0; i < validators[epoch].length; i++) {
					if (validators[epoch][i] != validator) {
						address(uint160(validators[epoch][i])).transfer(penaltyShare);
					}
					
				}
			}
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
		uint totalValidatorsNumber = validators[epoch].length;
		uint index = status[epoch][msg.sender].index;
		benignReportedByblockNumber[blockNumber][validator] = benignReportedByblockNumber[blockNumber][validator] | (2 ** index);
		uint setBits = getNumberOfSetBits(benignReportedByblockNumber[blockNumber][validator]);
		if (setBits >= totalValidatorsNumber.mulByFraction(50,100)) {
			uint256 penalty = calculateReward(epoch);
			if (validatorStakingFunds[epoch][validator] < penalty) {
				penalty = validatorStakingFunds[epoch][validator] ;
			}
			if (penalty > 0) {
				validatorStakingFunds[epoch][validator] -= penalty;
				validatorTotalStakingFunds[epoch][validator] -= penalty;
				benignReportedByblockNumber[blockNumber][validator] = 0;
				uint256 penaltyShare = penalty.mulByFraction(1,totalValidatorsNumber - 1);
				for (uint i=0; i < validators[epoch].length; i++) {
					if (validators[epoch][i] != validator) {
						address(uint160(validators[epoch][i])).transfer(penaltyShare);
					}
					
				}
			}
			 
		}
		
		emit Report(msg.sender, validator, false);
	}

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
		uint totalValidatorsNumber = validators[epoch].length;
		uint index = status[epoch][msg.sender].index;
		maliciousReportedByblockNumber[blockNumber][validator] = maliciousReportedByblockNumber[blockNumber][validator] | (2 ** index);
		uint setBits = getNumberOfSetBits(maliciousReportedByblockNumber[blockNumber][validator]);
		if (setBits >= totalValidatorsNumber.mulByFraction(50,100)) {
			uint256 penalty = validatorStakingFunds[epoch][validator];
			if (penalty > 0) {
				validatorStakingFunds[epoch][validator] -= penalty;
				validatorTotalStakingFunds[epoch][validator] -= penalty;
				maliciousReportedByblockNumber[blockNumber][validator] = 0;
				uint256 penaltyShare = penalty.mulByFraction(1,totalValidatorsNumber - 1);
				for (uint i=0; i < validators[epoch].length; i++) {
					if (validators[epoch][i] != validator) {
						address(uint160(validators[epoch][i])).transfer(penaltyShare);
					}
					
				}
			}
			 
		}
		
		
		proofs[msg.sender][validator][blockNumber] = proof;
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


	event InitiateChange(bytes32 indexed _parentHash, address[] _newSet);

	function initiateChange(bytes32 parentHash, address[] memory newSet)
		public	
	{
		emit InitiateChange(parentHash, newSet);
	}


	uint lastClaimedIssuanceBlock;

	function reward(address[] memory benefactors, uint16[] memory kind) public view onlySystem returns (address[] memory, uint256[] memory) {
		require(benefactors.length == kind.length);
		uint256 calculateRewardValue = calculateReward(block.number, lastClaimedIssuanceBlock);
		uint256[] memory rewards = new uint256[](benefactors.length);
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


//Remixd: remixd --remix-ide https://remix.ethereum.org -s ./ --read-only
