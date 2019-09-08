var RecentBlockReward = artifacts.require("RecentBlockReward");
var UserProfile = artifacts.require("UserProfile");
var PaymentChannels = artifacts.require("PaymentChannels");
module.exports = function(deployer, network, accounts) {
    deployer.deploy(RecentBlockReward, accounts[0]);
    deployer.deploy(UserProfile);
    deployer.deploy(PaymentChannels);
};