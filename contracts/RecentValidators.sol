// Copyright 2018, Parity Technologies Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// An owned validator set contract where the owner can add or remove validators.
// This is an abstract contract that provides the base logic for adding/removing
// validators and provides base implementations for the `ValidatorSet`
// interface. The base implementations of the misbehavior reporting functions
// perform validation on the reported and reporter validators according to the
// currently active validator set. The base implementation of `finalizeChange`
// validates that there are existing unfinalized changes.

//Remixd: remixd --remix-ide https://remix.ethereum.org -s ./
//Validator smart contract setup: Deploy RelaySet then RelayedOwnedSet then call SetRealy

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
	mapping(uint=>mapping(address  => AddressStatus)) public status;

	mapping(uint=> mapping(address=> uint256)) public validatorTotalStakingFunds;

	mapping(uint=> mapping(address=> uint256)) public validatorStakingFunds;

	mapping(uint=> mapping(address=> uint256)) public validatorWitnessesFunds;


	mapping(uint=> mapping(address=> uint256)) public validatorTotalWitnessesFunds;

	mapping(uint=> mapping(address=> mapping(address=> uint256))) public witnessStakingFundsForValidator;

	mapping(uint=> mapping(address=> mapping(address=> uint256))) public freeServiceProvidersFundsForValidator;

	mapping(uint=> mapping(address=> mapping(address=> uint256))) public freeServiceProvidersFreeMbs;

	mapping(uint=> mapping(address => address[])) public validatorWitnesses;

	mapping(uint=> mapping(address => address[])) public validatorFreeServiceProviders;



	modifier isValidator(address addr) {
		uint epoch = getCurrentEpoch();
		bool isIn = status[epoch][addr].isIn;
		uint index = status[epoch][addr].index;

		require(isIn && index < validators[epoch].length && validators[epoch][index] == addr);
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


	

	function validatorVoted(uint epoch, uint256 amount, address payable validator) private {
		validatorTotalStakingFunds[epoch][validator] += amount;
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
					emit ValidatorRemoved(epoch, existingValidator);
					break;
				}
			}
			
			if (status[epoch][validator].isIn)	{
				emit ValidatorAdded(epoch, validator);
			}
		}

	}

	function validatorAsCandidate(uint256 stakingFunds, uint256 witnessesFunds) public payable {
		uint epoch = getCurrentEpoch() + 1;
		require(stakingFunds + witnessesFunds == msg.value, "Transfered amount should be equal to stakingFunds + witnessesFunds");
		require(block.number < getCurrentValidatorsElectionEnd(), "Relayers election period has passed");
		require(epochBlocks.mulByFraction(calculateReward(epoch),maximumValidatorsNumber) <= stakingFunds, "Insufficient stakingFunds");

		validatorStakingFunds[epoch][msg.sender] += stakingFunds;
		validatorWitnessesFunds[epoch][msg.sender] += witnessesFunds;
		validatorVoted(epoch, msg.value, msg.sender);
		emit ValidatorProposed(epoch, msg.sender, stakingFunds, witnessesFunds);
	}

	function voteValidatorAsWitness(address payable validator) public payable {
		uint epoch = getCurrentEpoch() + 1;
		require(block.number < getCurrentValidatorsElectionEnd(), "Relayers election period has passed");
		require(validatorStakingFunds[epoch][msg.sender] > 0, "Validator not found");
		require(msg.sender.balance.mulByFraction(witnessRequiredBalancePercent,100) <= msg.value, "Invalid address balance");
		if (witnessStakingFundsForValidator[epoch][msg.sender][validator] == 0) {
			validatorWitnesses[epoch][validator].push(msg.sender);
		}
		witnessStakingFundsForValidator[epoch][msg.sender][validator] += msg.value;
		validatorTotalWitnessesFunds[epoch][validator] += msg.value;
		validatorVoted(epoch, msg.value, validator);
		emit ValidatorVotedByWitness(epoch, validator, msg.sender, msg.value);
	}

	function voteValidatorAsServiceProvider(address payable validator, uint freeContentInMb) public payable {
		uint epoch = getCurrentEpoch() + 1;
		require(block.number < getCurrentValidatorsElectionEnd(), "Relayers election period has passed");
		require(validatorStakingFunds[epoch][msg.sender] > 0, "Validator not found");
		require(freeContentInMb.mul(pricePerMb) == msg.value, "Transfered amount should be freeContentInMb * pricePerMb");
		if (freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] == 0) {
			validatorFreeServiceProviders[epoch][validator].push(msg.sender);
		}
		freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] += msg.value;
		freeServiceProvidersFreeMbs[epoch][msg.sender][validator] += freeContentInMb;

		validatorVoted(epoch, msg.value, validator);
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
			require(currentEpoch  > epoch, "Current epoch should be greater than requested");
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
			require(currentEpoch  > epoch, "Current epoch should be greater than requested");
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
			require(currentEpoch  > epoch, "Current epoch should be greater than requested");
		}
		uint256 amount = freeServiceProvidersFundsForValidator[epoch][msg.sender][validator];
		freeServiceProvidersFundsForValidator[epoch][msg.sender][validator] = 0;
		msg.sender.transfer(amount);
		emit FreeServiceProviderRefunded(epoch, msg.sender, validator, amount);	
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
	function getValidators(uint epoch)
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
		return validators[getCurrentEpoch()];
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

	// Report that a validator has misbehaved in a benign way.
	function reportBenign(address validator, uint blockNumber)
		public
		isValidator(msg.sender)
		isValidator(validator)
		isRecent(blockNumber)
	{
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

}
