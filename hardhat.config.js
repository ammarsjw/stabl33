require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-ethers");
require("dotenv").config();

module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.19',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    mumbai: {
      url: process.env.URL_MUMBAI,
      accounts: [process.env.PRIVATE_KEY_MUMBAI],
    },
    // goerli: {
    //   url: process.env.URL,
    //   accounts: [process.env.PRIVATE_KEY],
    // },
    // mainnet: {
    //   url: process.env.URL_MAIN,
    //   accounts: [process.env.PRIVATE_KEY_MAIN],
    //   chainId: 1,
    // },
  },
  etherscan: {
    apiKey: 'WPJFDVCHRSQNBVUM5I5WCAW65C69BT6B3V' // mumbai
    // apiKey: 'AYBZ53EN445WNPFP2IZ85RXRPB4FH5XBP7' // goerli
  },
};