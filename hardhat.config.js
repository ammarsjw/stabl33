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
        goerli: {
            url: process.env.URL_GOERLI,
            accounts: [process.env.PRIVATE_KEY_GOERLI],
        },
        mainnet: {
            url: process.env.URL_MAINNET,
            accounts: [process.env.PRIVATE_KEY_MAINNET],
            chainId: 1,
        },
    },
    etherscan: {
        apiKey: {
            mumbai: process.env.BLOCK_EXPLORER_API_KEY_POLYGON,
            goerli: process.env.BLOCK_EXPLORER_API_KEY_ETHEREUM,
            mainnet: process.env.BLOCK_EXPLORER_API_KEY_ETHEREUM,
        },
    },
};
