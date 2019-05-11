var RecentBlockReward = artifacts.require("RecentBlockReward");
module.exports = function(deployer, network, accounts) {
    deployer.deploy(RecentBlockReward, accounts[0]);

};