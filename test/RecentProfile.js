const UserProfile = artifacts.require("UserProfile");
contract('Profile', (accounts) => {

    it('testing profile ', async () => {
        const UserProfileInstance = await UserProfile.deployed();
        // var response = await RecentBlockRewardInstance.reward.call(["0x16A472DAE0dD16A0140aB26A2F92B426a5b21386"],[0],{ from: accounts[0] });
        // console.log(response[0][0]);
        // console.log(web3.utils.fromWei(response[1][0],'ether'));
        // // Write an assertion below to check the return value of ResponseMessage.
        // assert.equal(web3.utils.fromWei(response[1][0],'ether'), 10, 'Valid reward');
    });
});