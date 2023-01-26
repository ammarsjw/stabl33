// let HDWalletProvider = require('@truffle/hdwallet-provider');
// require("dotenv").config();

// goerli provider
// const provider = new HDWalletProvider(
//   process.env.PRIVATE_KEY,
//   process.env.URL
// );

// mainnet provider
// const provider = new HDWalletProvider(
//   process.env.PRIVATE_KEY_MAIN,
//   process.env.URL_MAIN
// );

const { ethers } = require("hardhat");
const { network, run } = require("hardhat");

// const {hre} = require("hardhat");
// const Web3 = require('web3');
// const web3 = new Web3(provider);

async function main() {
  // Deploying Treasury
  const treasury = await ethers.getContractFactory("  ");
  const treasuryContract = await treasury.deploy();
  await treasuryContract.deployed();
  console.log("Treasury deployed to:", treasuryContract.address);

  // Deploying ROI
  // const roi = await hre.ethers.getContractFactory("ROI");
  // const roiContract = await roi.deploy(treasuryContract.address);
  // await roiContract.deployed();
  // console.log("ROI deployed to:", roiContract.address);

  // // Deploying Stabl3PublicSale
  // const stabl3PublicSale = await hre.ethers.getContractFactory("Stabl3PublicSale");
  // const stabl3PublicSaleContract = await stabl3PublicSale.deploy(treasuryContract.address, roiContract.address);
  // await stabl3PublicSaleContract.deployed();
  // console.log("Stabl3PublicSale deployed to:", stabl3PublicSaleContract.address);

  // // Deploying Stabl3Staking
  // const stabl3Staking = await hre.ethers.getContractFactory("Stabl3Staking");
  // const stabl3StakingContract = await stabl3Staking.deploy(treasuryContract.address, roiContract.address);
  // await stabl3StakingContract.deployed();
  // console.log("Stabl3Staking deployed to:", stabl3StakingContract.address);

  // // Deploying Stabl3Borrowing
  // const stabl3Borrowing = await hre.ethers.getContractFactory("Stabl3Borrowing");
  // const stabl3BorrowingContract = await stabl3Borrowing.deploy(treasuryContract.address, roiContract.address);
  // await stabl3BorrowingContract.deployed();
  // console.log("Stabl3Borrowing deployed to:", stabl3BorrowingContract.address);

  // // Deploying Stabl3Bonding
  // const stabl3Bonding = await hre.ethers.getContractFactory("Stabl3Bonding");
  // const stabl3BondingContract = await stabl3Bonding.deploy(treasuryContract.address, roiContract.address);
  // await stabl3BondingContract.deployed();
  // console.log("Stabl3Bonding deployed to:", stabl3BondingContract.address);


  // let account = web3.eth.accounts.privateKeyToAccount(privatekey);
  // let gasPrice = await web3.eth.getGasPrice();
  // let gas;


  // // Initializing Treasury
  // const treasuryInstance = await hre.ethers.getContractAt("Treasury", treasuryContract.address);
  // gas = await treasuryInstance.methods.updateROI(treasuryContract.address).estimateGas({ from: account.address, gasPrice });
  // await treasuryInstance.methods.updateROI(treasuryContract.address).send({ from: account.address, gasPrice, gas });
  // let initArrayTreasury = [
  //   stabl3PublicSaleContract.address,
  //   stabl3StakingContract.address,
  //   stabl3BorrowingContract.address,
  //   stabl3BondingContract.address,
  // ];
  // gas = await treasuryInstance.methods.updatePermissionMultiple(initArrayTreasury, true).estimateGas({ from: account.address, gasPrice });
  // await treasuryInstance.methods.updatePermissionMultiple(initArrayTreasury, true).send({ from: account.address, gasPrice, gas });

  // // Initializing ROI
  // const roiInstance = await hre.ethers.getContractAt("ROI", roiContract.address);
  // gas = await roiInstance.methods.updateStabl3Staking(stabl3StakingContract.address).estimateGas({ from: account.address, gasPrice });
  // await roiInstance.methods.updateStabl3Staking(stabl3StakingContract.address).send({ from: account.address, gasPrice, gas });
  // let initArrayROI = [
  //   stabl3PublicSaleContract.address,
  //   stabl3BorrowingContract.address,
  //   stabl3BondingContract.address,
  // ];
  // gas = await roiInstance.methods.updatePermissionMultiple(initArrayROI, true).estimateGas({ from: account.address, gasPrice });
  // await roiInstance.methods.updatePermissionMultiple(initArrayROI, true).send({ from: account.address, gasPrice, gas });

  // // Initializing Stabl3PublicSale
  // const stabl3PublicSaleInstance = await hre.ethers.getContractAt("Stabl3PublicSale", stabl3PublicSaleContract.address);
  // gas = await stabl3PublicSaleInstance.methods.updateState(true).estimateGas({ from: account.address, gasPrice });
  // await stabl3PublicSaleInstance.methods.updateState(true).send({ from: account.address, gasPrice, gas });

  // // Initializing Stabl3Staking
  // const stabl3StakingInstance = await hre.ethers.getContractAt("Stabl3Staking", stabl3StakingContract.address);
  // gas = await stabl3StakingInstance.methods.updateState(true).estimateGas({ from: account.address, gasPrice });
  // await stabl3StakingInstance.methods.updateState(true).send({ from: account.address, gasPrice, gas });

  // // Initializing Stabl3Borrowing
  // const stabl3BorrowingInstance = await hre.ethers.getContractAt("Stabl3Borrowing", stabl3BorrowingContract.address);
  // gas = await stabl3BorrowingInstance.methods.updateState(true).estimateGas({ from: account.address, gasPrice });
  // await stabl3BorrowingInstance.methods.updateState(true).send({ from: account.address, gasPrice, gas });

  // const ucdAddress = await stabl3BorrowingInstance.methods.UCD().call();
  // const ucdInstance = await hre.ethers.getContractAt("contracts/tokens/UCD.sol:UCD", ucdAddress);
  // gas = await ucdInstance.methods.updatePermission(stabl3BorrowingContract.address, true).estimateGas({ from: account.address, gasPrice });
  // await ucdInstance.methods.updatePermission(stabl3BorrowingContract.address, true).send({ from: account.address, gasPrice });

  // // Initializing Stabl3Bonding
  // const stabl3BondingInstance = await hre.ethers.getContractAt("Stabl3Bonding", stabl3BondingContract.address);
  // gas = await stabl3BondingInstance.methods.updateState(true).estimateGas({ from: account.address, gasPrice });
  // await stabl3BondingInstance.methods.updateState(true).send({ from: account.address, gasPrice, gas });

  // // Verifying contracts
  // await new Promise(resolve => setTimeout(resolve, 20000));

  // verify(treasuryContract.address, []);
  // verify(roi.address, [treasuryContract.address]);
  // verify(stabl3PublicSale.address, [treasuryContract.address, roiContract.address]);
  // verify(stabl3Staking.address, [treasuryContract.address, roiContract.address]);
  // verify(stabl3Borrowing.address, [treasuryContract.address, roiContract.address]);
  // verify(stabl3Bonding.address, [treasuryContract.address, roiContract.address]);
}


async function verify(address, constructorArguments) {
  console.log(`verify ${address} with arguments ${constructorArguments.join(',')}`)
  await hre.run("verify:verify", {
    address,
    constructorArguments
  })
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});