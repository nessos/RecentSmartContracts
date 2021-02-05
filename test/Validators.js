const RecentValidators = artifacts.require("RecentValidators");
contract('RecentValidators', (accounts) => {
    var smartContractAddress = '0x91adc706407f87481a196B72281904110Ad8803B'; // Existing address
    function getTestContract() {
      return RecentValidators.at(smartContractAddress);
    }
    it('testing  ..', async () => {
        const RecentValidatorsInstance = await RecentValidators.deployed();
        const toBN = web3.utils.toBN;
        //const RecentValidatorsInstance = getTestContract();
        console.log(RecentValidatorsInstance.address);
        var getRequiredStakes = await RecentValidatorsInstance.getRequiredStakingFunds(2,{from: accounts[0]});
        console.log(web3.utils.fromWei(getRequiredStakes));
        var witnessesFunds = web3.utils.toWei("10", "ether");
        console.log(web3.utils.fromWei(witnessesFunds));
        var total = toBN(getRequiredStakes).add(toBN(witnessesFunds));
        console.log(web3.utils.fromWei(total));
        var response = await RecentValidatorsInstance.validatorAsCandidate(getRequiredStakes, witnessesFunds, {value: total, from: accounts[0] });
        console.log(response);

    });
});