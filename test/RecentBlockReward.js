const RecentBlockReward = artifacts.require("RecentBlockReward");
contract('RecentBlockReward', (accounts) => {

    it('testing reward of RecentBlockReward', async () => {
        const RecentBlockRewardInstance = await RecentBlockReward.deployed();
         var response = await RecentBlockRewardInstance.reward.call(["0x16A472DAE0dD16A0140aB26A2F92B426a5b21386"],[0],{ from: accounts[0] });
        console.log(response[0][0]);
        console.log(web3.utils.fromWei(response[1][0],'ether'));
        // Write an assertion below to check the return value of ResponseMessage.
        assert.equal('something', 'something', 'A correctness property about ResponseMessage of HelloBlockchain');
    });

    

});