const RecentBlockReward = artifacts.require("RecentBlockReward");
contract('RecentBlockReward', (accounts) => {
    var smartContractAddress = '0x499C3893e931BaABa2546BFd672DcF86d42e0F0c'; // Existing address
    function getTestContract() {
      return RecentBlockReward.at(smartContractAddress);
    }
    it('testing reward of RecentBlockReward', async () => {
        //const RecentBlockRewardInstance = await RecentBlockReward.deployed();
        const RecentBlockRewardInstance = await getTestContract();
        console.log(RecentBlockRewardInstance.address);
        var response = await RecentBlockRewardInstance.reward.call(["0x16A472DAE0dD16A0140aB26A2F92B426a5b21386"],[0],{ from: accounts[0] });
        console.log(response[0][0]);
        console.log(web3.utils.fromWei(response[1][0],'ether'));
        // Write an assertion below to check the return value of ResponseMessage.
        assert.equal(web3.utils.fromWei(response[1][0],'ether'), 10, 'Valid reward');
    });
});