const PaymentChannel = artifacts.require("PaymentChannel");
contract('PaymentChannel', (accounts) => {
    var smartContractAddress = '0xbf9F727726BDa3fd56874a2CC04A998e3f0AB6Af'; // Existing address
    function getTestContract() {
      return PaymentChannel.at(smartContractAddress);
    }
    it('testing channel creation', async () => {
        //const PaymentChannelInstance = await PaymentChannel.deployed();
        const PaymentChannelInstance = await getTestContract();
        console.log(PaymentChannelInstance.address);
        var numberOfUserChannels = await PaymentChannelInstance.getUserTotalChannels({from: accounts[0] });
        console.log(numberOfUserChannels);
        var response = await PaymentChannelInstance.openChannel("0x47e437a8a1d35529814835a55e97dbce10bd522f", 10, {value: web3.utils.toWei("0.001"), from: accounts[0] });
        console.log(response);
        var channelId = await PaymentChannelInstance.getChannelId(numberOfUserChannels,{from: accounts[0] });
        console.log(web3.utils.toHex(channelId));
        // console.log(web3.utils.fromWei(response[1][0],'ether'));
        // // Write an assertion below to check the return value of ResponseMessage.
        // assert.equal(web3.utils.fromWei(response[1][0],'ether'), 10, 'Valid reward');
    });
});