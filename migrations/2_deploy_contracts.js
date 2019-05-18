var RecentBlockReward = artifacts.require("RecentBlockReward");
var UserProfile = artifacts.require("UserProfile");
module.exports = function(deployer, network, accounts) {
    deployer.deploy(RecentBlockReward, accounts[0]);
    deployer.deploy(UserProfile);
};