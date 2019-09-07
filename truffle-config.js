const HDWalletProvider = require('truffle-hdwallet-provider');
const fs = require('fs');

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    development: {
      network_id: "*",
      host: 'localhost',
      port: 8545
    },
    recent: {
      provider: () => new HDWalletProvider("combine close before lawsuit asthma glimpse yard debate mixture stool adjust ride", "http://127.0.0.1:8545"),
      from: "0x3d176d013550b48974c1d2f0b18c6df1ff71391e",
      network_id: "12858966",
      gasPrice: 1,
      confirmations: 0, // # of confs to wait between deployments. (default: 0)
      skipDryRun: true
    }
  },
  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },
  // Configure your compilers
  compilers: {
    solc: {
      version : "0.5.8",
      settings: {
        optimizer: {
          enabled: true, 
          runs: 200    
        }
      }
    }
  }
};
