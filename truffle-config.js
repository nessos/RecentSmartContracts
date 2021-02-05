const HDWalletProvider = require('truffle-hdwallet-provider');
const fs = require('fs');
module.exports = {
  networks: {
    development: {
      network_id: "*",
      host: 'localhost',
      port: 8545
    },
    recentlocal: {
      provider: () => new HDWalletProvider("combine close before lawsuit asthma glimpse yard debate mixture stool adjust ride", "http://localhost:8545"),
      from: "0x3d176d013550b48974c1d2f0b18c6df1ff71391e",
      network_id: "12858955",
      host: 'localhost',
      port: 8545,
      gasPrice: 1000000000,
      confirmations: 0
    },
    recent: {
      provider: () => new HDWalletProvider("combine close before lawsuit asthma glimpse yard debate mixture stool adjust ride", "http://ec2-3-124-182-37.eu-central-1.compute.amazonaws.com:8545"),
      from: "0x3d176d013550b48974c1d2f0b18c6df1ff71391e",
      network_id: "12858956",
      host: 'http://ec2-3-124-182-37.eu-central-1.compute.amazonaws.com',
      port: 8545,
      gasPrice: 1000000000,
      confirmations: 0
    },
    loc_development_development: {
      network_id: "*",
      port: 8545,
      host: "127.0.0.1"
    }
  },
  mocha: {},
  compilers: {
    solc: {
      version: "0.5.8",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
};
