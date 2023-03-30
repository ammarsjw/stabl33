let HDWalletProvider = require('@truffle/hdwallet-provider')
require("dotenv").config()

// mumbai provider
const provider = new HDWalletProvider(
  process.env.PRIVATE_KEY_MUMBAI,
  process.env.URL_MUMBAI
)

// goerli provider
// const provider = new HDWalletProvider(
//   process.env.PRIVATE_KEY,
//   process.env.URL
// )

// mainnet provider
// const provider = new HDWalletProvider(
//   process.env.PRIVATE_KEY_MAIN,
//   process.env.URL_MAIN
// )

const hre = require("hardhat")
const Web3 = require('web3')
const web3 = new Web3(provider)

async function main() {
  // // checking gas price
  // let gasPrice = 1000000
  // while (gasPrice > 100) {
  //   feeData = await hre.ethers.provider.getFeeData()
  //   gasPrice = hre.ethers.utils.formatUnits(feeData.gasPrice, "gwei")
  //   console.log(gasPrice);
  // }

  // Deploying Treasury
  const treasury = await hre.ethers.getContractFactory("Treasury")
  const treasuryContract = await treasury.deploy()
  await treasuryContract.deployed()
  const treasuryTxHash = treasuryContract.deployTransaction.hash
  let treasuryTxReceipt = await treasuryContract.provider.getTransactionReceipt(treasuryTxHash)
  console.log("(Graph) Treasury deployed to:", treasuryContract.address)
  console.log("at block number:", treasuryTxReceipt.blockNumber)

  // Deploying ROI
  const roi = await hre.ethers.getContractFactory("ROI")
  const roiContract = await roi.deploy(treasuryContract.address)
  await roiContract.deployed()
  const roiTxHash = roiContract.deployTransaction.hash
  let roiTxReceipt = await roiContract.provider.getTransactionReceipt(roiTxHash)
  console.log("(Graph) ROI deployed to:", roiContract.address)
  console.log("at block number:", roiTxReceipt.blockNumber)

  // Deploying Stabl3PublicSale
  const stabl3PublicSale = await hre.ethers.getContractFactory("Stabl3PublicSale")
  const stabl3PublicSaleContract = await stabl3PublicSale.deploy(treasuryContract.address, roiContract.address)
  await stabl3PublicSaleContract.deployed()
  const stabl3PublicSaleTxHash = stabl3PublicSaleContract.deployTransaction.hash
  let stabl3PublicSaleTxReceipt = await stabl3PublicSaleContract.provider.getTransactionReceipt(stabl3PublicSaleTxHash)
  console.log("Stabl3PublicSale deployed to:", stabl3PublicSaleContract.address)
  console.log("at block number:", stabl3PublicSaleTxReceipt.blockNumber)

  // Deploying Stabl3Staking
  const stabl3Staking = await hre.ethers.getContractFactory("Stabl3Staking")
  const stabl3StakingContract = await stabl3Staking.deploy(treasuryContract.address, roiContract.address)
  await stabl3StakingContract.deployed()
  const stabl3StakingTxHash = stabl3StakingContract.deployTransaction.hash
  let stabl3StakingTxReceipt = await stabl3StakingContract.provider.getTransactionReceipt(stabl3StakingTxHash)
  console.log("(Graph) Stabl3Staking deployed to:", stabl3StakingContract.address)
  console.log("at block number:", stabl3StakingTxReceipt.blockNumber)

  // Deploying Stabl3Borrowing
  const stabl3Borrowing = await hre.ethers.getContractFactory("Stabl3Borrowing")
  const stabl3BorrowingContract = await stabl3Borrowing.deploy(treasuryContract.address, roiContract.address)
  await stabl3BorrowingContract.deployed()
  const stabl3BorrowingTxHash = stabl3BorrowingContract.deployTransaction.hash
  let stabl3BorrowingTxReceipt = await stabl3BorrowingContract.provider.getTransactionReceipt(stabl3BorrowingTxHash)
  console.log("(Graph) Stabl3Borrowing deployed to:", stabl3BorrowingContract.address)
  console.log("at block number:", stabl3BorrowingTxReceipt.blockNumber)

  // Deploying Stabl3Bonding
  const stabl3Bonding = await hre.ethers.getContractFactory("Stabl3Bonding")
  const stabl3BondingContract = await stabl3Bonding.deploy(treasuryContract.address, roiContract.address)
  await stabl3BondingContract.deployed()
  const stabl3BondingTxHash = stabl3BondingContract.deployTransaction.hash
  let stabl3BondingTxReceipt = await stabl3BondingContract.provider.getTransactionReceipt(stabl3BondingTxHash)
  console.log("(Graph) Stabl3Bonding deployed to:", stabl3BondingContract.address)
  console.log("at block number:", stabl3BondingTxReceipt.blockNumber)


  let treasuryContractAddress = treasuryContract.address
  let roiContractAddress = roiContract.address
  let stabl3PublicSaleContractAddress = stabl3PublicSaleContract.address
  let stabl3StakingContractAddress = stabl3StakingContract.address
  let stabl3BorrowingContractAddress = stabl3BorrowingContract.address
  let stabl3BondingContractAddress = stabl3BondingContract.address
  // let treasuryContractAddress = ""
  // let roiContractAddress = ""
  // let stabl3PublicSaleContractAddress = ""
  // let stabl3StakingContractAddress = ""
  // let stabl3BorrowingContractAddress = ""
  // let stabl3BondingContractAddress = ""


  // Initializing Treasury
  const treasuryInstance = await hre.ethers.getContractAt("Treasury", treasuryContractAddress)
  await treasuryInstance.updateROI(roiContractAddress)
  let initArrayTreasury = [
    stabl3PublicSaleContractAddress,
    stabl3StakingContractAddress,
    stabl3BorrowingContractAddress,
    stabl3BondingContractAddress,
  ]
  await treasuryInstance.updatePermissionMultiple(initArrayTreasury, true)
  console.log("Treasury initialized")

  // Initializing ROI
  const roiInstance = await hre.ethers.getContractAt("ROI", roiContractAddress)
  await roiInstance.updateStabl3Staking(stabl3StakingContractAddress)
  let initArrayROI = [
    stabl3PublicSaleContractAddress,
    stabl3BorrowingContractAddress,
    stabl3BondingContractAddress,
  ]
  await roiInstance.updatePermissionMultiple(initArrayROI, true)
  console.log("ROI initialized")

  // Initializing Stabl3PublicSale
  const stabl3PublicSaleInstance = await hre.ethers.getContractAt("Stabl3PublicSale", stabl3PublicSaleContractAddress)
  await stabl3PublicSaleInstance.updateState(true)
  console.log("Stabl3PublicSale initialized")

  // Initializing Stabl3Staking
  const stabl3StakingInstance = await hre.ethers.getContractAt("Stabl3Staking", stabl3StakingContractAddress)
  await stabl3StakingInstance.updateState(true)
  console.log("Stabl3Staking initialized")

  // Initializing Stabl3Borrowing
  const stabl3BorrowingInstance = await hre.ethers.getContractAt("Stabl3Borrowing", stabl3BorrowingContractAddress)
  await stabl3BorrowingInstance.updateState(true)

  const ucdContractAddress = await stabl3BorrowingInstance.UCD()
  const ucdInstance = await hre.ethers.getContractAt("contracts/tokens/UCD.sol:UCD", ucdContractAddress)
  await ucdInstance.updatePermission(stabl3BorrowingContractAddress, true)
  console.log("Stabl3Borrowing initialized")

  // Initializing Stabl3Bonding
  const stabl3BondingInstance = await hre.ethers.getContractAt("Stabl3Bonding", stabl3BondingContractAddress)
  await stabl3BondingInstance.updateState(true)
  console.log("Stabl3Bonding initialized")


  // Verifying contracts
  await new Promise(resolve => setTimeout(resolve, 20000))
  await verify(treasuryContractAddress, [])
  await verify(roiContractAddress, [treasuryContractAddress])
  await verify(stabl3PublicSaleContractAddress, [treasuryContractAddress, roiContractAddress])
  await verify(stabl3StakingContractAddress, [treasuryContractAddress, roiContractAddress])
  await verify(stabl3BorrowingContractAddress, [treasuryContractAddress, roiContractAddress])
  await verify(stabl3BondingContractAddress, [treasuryContractAddress, roiContractAddress])


  process.exit()
}


async function verify(address, constructorArguments) {
  console.log(`verify ${address} with arguments ${constructorArguments.join(',')}`)
  try {  
    await hre.run("verify:verify", {
      address,
      constructorArguments
    })
  } catch (error) { console.log(error) }
}


main().catch((error) => {
  console.error(error)
  process.exitCode = 1
  process.exit()
})