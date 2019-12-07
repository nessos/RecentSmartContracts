const PaymentChannels = artifacts.require("PaymentChannels");
contract('PaymentChannels', (accounts) => {
    var smartContractAddress = '0xbf9F727726BDa3fd56874a2CC04A998e3f0AB6Af'; // Existing address
    function getTestContract() {
      return PaymentChannels.at(smartContractAddress);
    }
    it('testing Relayers', async () => {
        const PaymentChannelInstance = await PaymentChannels.deployed();
        //const PaymentChannelInstance = await getTestContract();
        console.log(PaymentChannelInstance.address);
        var ReleayerDomain = "https://www.google.com";

        var requiredAmount = await PaymentChannelInstance.getFundRequiredForRelayer.call(150,10000,10);

        //string memory domain, bytes32 name, uint fee, uint maxUsers, uint maxCoins, uint maxTxThroughput, uint offchainTxDelay
        var addRelayerResponse = await PaymentChannelInstance.addRelayer(ReleayerDomain, web3.utils.fromUtf8("Google"), 10, 150, 10000, 10, 5000, {value: requiredAmount, from: accounts[0] });
        //console.log(addRelayerResponse.receipt.logs);

        var domainHash =  web3.utils.soliditySha3(ReleayerDomain);
        console.log(domainHash);

        var testHashingResponse = await PaymentChannelInstance.testHashing.call(domainHash,ReleayerDomain);
        //console.log(testHashingResponse);


        var relayerResponse = await PaymentChannelInstance.relayers.call(accounts[0]);
        console.log("Relayer:" + JSON.stringify(relayerResponse));



        var depositAmount = 0.0001;
        var depositToRelayerResponse = await PaymentChannelInstance.depositToRelayer(accounts[0], 1, {value: web3.utils.toWei(depositAmount.toString()), from: accounts[1] });
        //console.log(depositToRelayerResponse.receipt.logs);

        var voteRelayerResponse = await PaymentChannelInstance.voteRelayer(domainHash,480, {from: accounts[0] });
        //console.log(voteRelayerResponse);

        var voteRelayerResponse = await PaymentChannelInstance.voteRelayer(domainHash,460, {from: accounts[0] });
        //console.log(voteRelayerResponse);

        var getRelayerRatingResponse = await PaymentChannelInstance.getRelayerRating.call(domainHash);
        //console.log("Relayer rating:" + getRelayerRatingResponse.toNumber());

        assert.equal(460, getRelayerRatingResponse.toNumber(), 'Valid Rating');

        var depositToRelayerResponse = await PaymentChannelInstance.depositToRelayer(domainHash,1, {value: web3.utils.toWei(depositAmount.toString()), from: accounts[0] });
        //console.log(depositToRelayerResponse.receipt.logs);

        var userDepositOnRelayerResponse = await PaymentChannelInstance.userDepositOnRelayer.call(accounts[0], domainHash);
        //console.log("User balance:" + web3.utils.fromWei(userDepositOnRelayerResponse.balance));

        assert.equal(depositAmount + depositAmount, web3.utils.fromWei(userDepositOnRelayerResponse.balance), 'Valid deposit amount');

    });
});