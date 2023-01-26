let HDWalletProvider = require('@truffle/hdwallet-provider');
require("dotenv").config();

// goerli provider
const provider = new HDWalletProvider(
  process.env.PRIVATE_KEY,
  process.env.URL
);

// mainnet provider
// const provider = new HDWalletProvider(
//   process.env.PRIVATE_KEY_MAIN,
//   process.env.URL_MAIN
// );

const hre = require("hardhat");
const Web3 = require('web3');
const web3 = new Web3(provider);

async function main() {
  // // Deploying Treasury
  // const treasury = await hre.ethers.getContractFactory("Treasury");
  // const treasuryContract = await treasury.deploy();
  // await treasuryContract.deployed();
  // console.log("Treasury deployed to:", treasuryContract.address);

  // // Deploying ROI
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


  // let treasuryContractAddress = treasuryContract.address;
  // let roiContractAddress = roiContract.address;
  // let stabl3PublicSaleContractAddress = stabl3PublicSaleContract.address;
  // let stabl3StakingContractAddress = stabl3StakingContract.address;
  // let stabl3BorrowingContractAddress = stabl3BorrowingContract.address;
  // let stabl3BondingContractAddress = stabl3BondingContract.address;
  let treasuryContractAddress = "0x8dD7aa7615A2811c754b7e3185eD21CDdF2d11B5";
  let roiContractAddress = "0x174495aceB0a92394eB430D35A6480A7584A6DfE";
  let stabl3PublicSaleContractAddress = "0x759AEBcc859BaC14133b6971C31e7e699c7BA1DC";
  let stabl3StakingContractAddress = "0x2Da9147F9449a369384e62b3FB0E9853DC8B983B";
  let stabl3BorrowingContractAddress = "0x82b80F6d5876e8805431828E3Dd8332C56f5c969";
  let stabl3BondingContractAddress = "0xD8F0b5A6f397fb86acF01bd60dB5964461Cc8Cd6";


  // Initializing Treasury
  const treasuryInstance = await hre.ethers.getContractAt("Treasury", treasuryContractAddress);
  await treasuryInstance.updateROI(roiContractAddress);
  let initArrayTreasury = [
    stabl3PublicSaleContractAddress,
    stabl3StakingContractAddress,
    stabl3BorrowingContractAddress,
    stabl3BondingContractAddress,
  ];
  await treasuryInstance.updatePermissionMultiple(initArrayTreasury, true);
  console.log("Treasury Initialized")

  // Initializing ROI
  const roiInstance = await hre.ethers.getContractAt("ROI", roiContractAddress);
  await roiInstance.updateStabl3Staking(stabl3StakingContractAddress);
  let initArrayROI = [
    stabl3PublicSaleContractAddress,
    stabl3BorrowingContractAddress,
    stabl3BondingContractAddress,
  ];
  await roiInstance.updatePermissionMultiple(initArrayROI, true);
  console.log("ROI Initialized")

  // Initializing Stabl3PublicSale
  const stabl3PublicSaleInstance = await hre.ethers.getContractAt("Stabl3PublicSale", stabl3PublicSaleContractAddress);
  await stabl3PublicSaleInstance.updateState(true);
  console.log("Stabl3PublicSale Initialized")

  // Initializing Stabl3Staking
  const stabl3StakingInstance = await hre.ethers.getContractAt("Stabl3Staking", stabl3StakingContractAddress);
  await stabl3StakingInstance.updateState(true);
  console.log("Stabl3Staking Initialized")

  // Initializing Stabl3Borrowing
  const stabl3BorrowingInstance = await hre.ethers.getContractAt("Stabl3Borrowing", stabl3BorrowingContractAddress);
  await stabl3BorrowingInstance.updateState(true);

  const ucdAddress = await stabl3BorrowingInstance.UCD().call();
  const ucdInstance = await hre.ethers.getContractAt("contracts/tokens/UCD.sol:UCD", ucdAddress);
  await ucdInstance.updatePermission(stabl3BorrowingContractAddress, true);
  console.log("Stabl3Borrowing Initialized")

  // Initializing Stabl3Bonding
  const stabl3BondingInstance = await hre.ethers.getContractAt("Stabl3Bonding", stabl3BondingContractAddress);
  await stabl3BondingInstance.updateState(true);
  console.log("Stabl3Bonding Initialized")

  // Verifying contracts
  await new Promise(resolve => setTimeout(resolve, 20000));
  verify(treasuryContractAddress, []);
  verify(roiContractAddress, [treasuryContractAddress]);
  verify(stabl3PublicSaleContractAddress, [treasuryContractAddress, roiContractAddress]);
  verify(stabl3StakingContractAddress, [treasuryContractAddress, roiContractAddress]);
  verify(stabl3BorrowingContractAddress, [treasuryContractAddress, roiContractAddress]);
  verify(stabl3BondingContractAddress, [treasuryContractAddress, roiContractAddress]);

  console.log("Batch Job Complete");

  process.exit();
}


async function verify(address, constructorArguments) {
  await hre.run("verify:verify", {
    address,
    constructorArguments
  })
  console.log(`verified ${address} with arguments ${constructorArguments.join(',')}`)
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});