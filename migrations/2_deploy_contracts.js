var RecentValidators = artifacts.require("RecentValidators");
var PaymentChannels = artifacts.require("PaymentChannels");
module.exports = function(deployer, network, accounts) {
    deployer.deploy(RecentValidators, ["0x02775b8ef251abc06950d3be4522d71d715bc03a"]);
    deployer.deploy(PaymentChannels);
};