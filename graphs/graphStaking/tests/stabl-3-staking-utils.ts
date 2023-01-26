import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  ClaimedLendingStabl3,
  OwnershipTransferred,
  Stake,
  Unstake,
  UpdatedHQ,
  UpdatedLendingStabl3ClaimTime,
  UpdatedLendingStabl3Percentage,
  UpdatedLockTime,
  UpdatedPermission,
  UpdatedROI,
  UpdatedTreasury,
  UpdatedUnstakeFeePercentage,
  WithdrewReward
} from "../generated/Stabl3Staking/Stabl3Staking"

export function createClaimedLendingStabl3Event(
  user: Address,
  index: BigInt,
  token: Address,
  amountTokenLending: BigInt,
  amountStabl3Lending: BigInt,
  totalAmountStabl3Withdrawn: BigInt,
  timestamp: BigInt
): ClaimedLendingStabl3 {
  let claimedLendingStabl3Event = changetype<ClaimedLendingStabl3>(
    newMockEvent()
  )

  claimedLendingStabl3Event.parameters = new Array()

  claimedLendingStabl3Event.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  claimedLendingStabl3Event.parameters.push(
    new ethereum.EventParam("index", ethereum.Value.fromUnsignedBigInt(index))
  )
  claimedLendingStabl3Event.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )
  claimedLendingStabl3Event.parameters.push(
    new ethereum.EventParam(
      "amountTokenLending",
      ethereum.Value.fromUnsignedBigInt(amountTokenLending)
    )
  )
  claimedLendingStabl3Event.parameters.push(
    new ethereum.EventParam(
      "amountStabl3Lending",
      ethereum.Value.fromUnsignedBigInt(amountStabl3Lending)
    )
  )
  claimedLendingStabl3Event.parameters.push(
    new ethereum.EventParam(
      "totalAmountStabl3Withdrawn",
      ethereum.Value.fromUnsignedBigInt(totalAmountStabl3Withdrawn)
    )
  )
  claimedLendingStabl3Event.parameters.push(
    new ethereum.EventParam(
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )

  return claimedLendingStabl3Event
}

export function createOwnershipTransferredEvent(
  previousOwner: Address,
  newOwner: Address
): OwnershipTransferred {
  let ownershipTransferredEvent = changetype<OwnershipTransferred>(
    newMockEvent()
  )

  ownershipTransferredEvent.parameters = new Array()

  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam(
      "previousOwner",
      ethereum.Value.fromAddress(previousOwner)
    )
  )
  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam("newOwner", ethereum.Value.fromAddress(newOwner))
  )

  return ownershipTransferredEvent
}

export function createStakeEvent(
  user: Address,
  index: BigInt,
  stakingType: i32,
  token: Address,
  amountToken: BigInt,
  totalAmountToken: BigInt,
  isLend: boolean,
  timestamp: BigInt
): Stake {
  let stakeEvent = changetype<Stake>(newMockEvent())

  stakeEvent.parameters = new Array()

  stakeEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  stakeEvent.parameters.push(
    new ethereum.EventParam("index", ethereum.Value.fromUnsignedBigInt(index))
  )
  stakeEvent.parameters.push(
    new ethereum.EventParam(
      "stakingType",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(stakingType))
    )
  )
  stakeEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )
  stakeEvent.parameters.push(
    new ethereum.EventParam(
      "amountToken",
      ethereum.Value.fromUnsignedBigInt(amountToken)
    )
  )
  stakeEvent.parameters.push(
    new ethereum.EventParam(
      "totalAmountToken",
      ethereum.Value.fromUnsignedBigInt(totalAmountToken)
    )
  )
  stakeEvent.parameters.push(
    new ethereum.EventParam("isLend", ethereum.Value.fromBoolean(isLend))
  )
  stakeEvent.parameters.push(
    new ethereum.EventParam(
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )

  return stakeEvent
}

export function createUnstakeEvent(
  user: Address,
  index: BigInt,
  token: Address,
  amountToken: BigInt,
  reward: BigInt,
  stakingType: i32,
  isLend: boolean
): Unstake {
  let unstakeEvent = changetype<Unstake>(newMockEvent())

  unstakeEvent.parameters = new Array()

  unstakeEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  unstakeEvent.parameters.push(
    new ethereum.EventParam("index", ethereum.Value.fromUnsignedBigInt(index))
  )
  unstakeEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )
  unstakeEvent.parameters.push(
    new ethereum.EventParam(
      "amountToken",
      ethereum.Value.fromUnsignedBigInt(amountToken)
    )
  )
  unstakeEvent.parameters.push(
    new ethereum.EventParam("reward", ethereum.Value.fromUnsignedBigInt(reward))
  )
  unstakeEvent.parameters.push(
    new ethereum.EventParam(
      "stakingType",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(stakingType))
    )
  )
  unstakeEvent.parameters.push(
    new ethereum.EventParam("isLend", ethereum.Value.fromBoolean(isLend))
  )

  return unstakeEvent
}

export function createUpdatedHQEvent(
  newHQ: Address,
  oldHQ: Address
): UpdatedHQ {
  let updatedHqEvent = changetype<UpdatedHQ>(newMockEvent())

  updatedHqEvent.parameters = new Array()

  updatedHqEvent.parameters.push(
    new ethereum.EventParam("newHQ", ethereum.Value.fromAddress(newHQ))
  )
  updatedHqEvent.parameters.push(
    new ethereum.EventParam("oldHQ", ethereum.Value.fromAddress(oldHQ))
  )

  return updatedHqEvent
}

export function createUpdatedLendingStabl3ClaimTimeEvent(
  newLendingStabl3ClaimTime: BigInt,
  oldLendingStabl3ClaimTime: BigInt
): UpdatedLendingStabl3ClaimTime {
  let updatedLendingStabl3ClaimTimeEvent = changetype<
    UpdatedLendingStabl3ClaimTime
  >(newMockEvent())

  updatedLendingStabl3ClaimTimeEvent.parameters = new Array()

  updatedLendingStabl3ClaimTimeEvent.parameters.push(
    new ethereum.EventParam(
      "newLendingStabl3ClaimTime",
      ethereum.Value.fromUnsignedBigInt(newLendingStabl3ClaimTime)
    )
  )
  updatedLendingStabl3ClaimTimeEvent.parameters.push(
    new ethereum.EventParam(
      "oldLendingStabl3ClaimTime",
      ethereum.Value.fromUnsignedBigInt(oldLendingStabl3ClaimTime)
    )
  )

  return updatedLendingStabl3ClaimTimeEvent
}

export function createUpdatedLendingStabl3PercentageEvent(
  newLendingStabl3Percentage: BigInt,
  oldLendingStabl3Percentage: BigInt
): UpdatedLendingStabl3Percentage {
  let updatedLendingStabl3PercentageEvent = changetype<
    UpdatedLendingStabl3Percentage
  >(newMockEvent())

  updatedLendingStabl3PercentageEvent.parameters = new Array()

  updatedLendingStabl3PercentageEvent.parameters.push(
    new ethereum.EventParam(
      "newLendingStabl3Percentage",
      ethereum.Value.fromUnsignedBigInt(newLendingStabl3Percentage)
    )
  )
  updatedLendingStabl3PercentageEvent.parameters.push(
    new ethereum.EventParam(
      "oldLendingStabl3Percentage",
      ethereum.Value.fromUnsignedBigInt(oldLendingStabl3Percentage)
    )
  )

  return updatedLendingStabl3PercentageEvent
}

export function createUpdatedLockTimeEvent(
  newLockTimes: Array<BigInt>,
  oldLockTimes: Array<BigInt>
): UpdatedLockTime {
  let updatedLockTimeEvent = changetype<UpdatedLockTime>(newMockEvent())

  updatedLockTimeEvent.parameters = new Array()

  updatedLockTimeEvent.parameters.push(
    new ethereum.EventParam(
      "newLockTimes",
      ethereum.Value.fromUnsignedBigIntArray(newLockTimes)
    )
  )
  updatedLockTimeEvent.parameters.push(
    new ethereum.EventParam(
      "oldLockTimes",
      ethereum.Value.fromUnsignedBigIntArray(oldLockTimes)
    )
  )

  return updatedLockTimeEvent
}

export function createUpdatedPermissionEvent(
  contractAddress: Address,
  state: boolean
): UpdatedPermission {
  let updatedPermissionEvent = changetype<UpdatedPermission>(newMockEvent())

  updatedPermissionEvent.parameters = new Array()

  updatedPermissionEvent.parameters.push(
    new ethereum.EventParam(
      "contractAddress",
      ethereum.Value.fromAddress(contractAddress)
    )
  )
  updatedPermissionEvent.parameters.push(
    new ethereum.EventParam("state", ethereum.Value.fromBoolean(state))
  )

  return updatedPermissionEvent
}

export function createUpdatedROIEvent(
  newROI: Address,
  oldROI: Address
): UpdatedROI {
  let updatedRoiEvent = changetype<UpdatedROI>(newMockEvent())

  updatedRoiEvent.parameters = new Array()

  updatedRoiEvent.parameters.push(
    new ethereum.EventParam("newROI", ethereum.Value.fromAddress(newROI))
  )
  updatedRoiEvent.parameters.push(
    new ethereum.EventParam("oldROI", ethereum.Value.fromAddress(oldROI))
  )

  return updatedRoiEvent
}

export function createUpdatedTreasuryEvent(
  newTreasury: Address,
  oldTreasury: Address
): UpdatedTreasury {
  let updatedTreasuryEvent = changetype<UpdatedTreasury>(newMockEvent())

  updatedTreasuryEvent.parameters = new Array()

  updatedTreasuryEvent.parameters.push(
    new ethereum.EventParam(
      "newTreasury",
      ethereum.Value.fromAddress(newTreasury)
    )
  )
  updatedTreasuryEvent.parameters.push(
    new ethereum.EventParam(
      "oldTreasury",
      ethereum.Value.fromAddress(oldTreasury)
    )
  )

  return updatedTreasuryEvent
}

export function createUpdatedUnstakeFeePercentageEvent(
  newUnstakeFeePercentage: BigInt,
  oldUnstakeFeePercentage: BigInt
): UpdatedUnstakeFeePercentage {
  let updatedUnstakeFeePercentageEvent = changetype<
    UpdatedUnstakeFeePercentage
  >(newMockEvent())

  updatedUnstakeFeePercentageEvent.parameters = new Array()

  updatedUnstakeFeePercentageEvent.parameters.push(
    new ethereum.EventParam(
      "newUnstakeFeePercentage",
      ethereum.Value.fromUnsignedBigInt(newUnstakeFeePercentage)
    )
  )
  updatedUnstakeFeePercentageEvent.parameters.push(
    new ethereum.EventParam(
      "oldUnstakeFeePercentage",
      ethereum.Value.fromUnsignedBigInt(oldUnstakeFeePercentage)
    )
  )

  return updatedUnstakeFeePercentageEvent
}

export function createWithdrewRewardEvent(
  user: Address,
  index: BigInt,
  token: Address,
  rewardWithdrawn: BigInt,
  totalRewardWithdrawn: BigInt,
  isLend: boolean,
  timestamp: BigInt
): WithdrewReward {
  let withdrewRewardEvent = changetype<WithdrewReward>(newMockEvent())

  withdrewRewardEvent.parameters = new Array()

  withdrewRewardEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  withdrewRewardEvent.parameters.push(
    new ethereum.EventParam("index", ethereum.Value.fromUnsignedBigInt(index))
  )
  withdrewRewardEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )
  withdrewRewardEvent.parameters.push(
    new ethereum.EventParam(
      "rewardWithdrawn",
      ethereum.Value.fromUnsignedBigInt(rewardWithdrawn)
    )
  )
  withdrewRewardEvent.parameters.push(
    new ethereum.EventParam(
      "totalRewardWithdrawn",
      ethereum.Value.fromUnsignedBigInt(totalRewardWithdrawn)
    )
  )
  withdrewRewardEvent.parameters.push(
    new ethereum.EventParam("isLend", ethereum.Value.fromBoolean(isLend))
  )
  withdrewRewardEvent.parameters.push(
    new ethereum.EventParam(
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )

  return withdrewRewardEvent
}
