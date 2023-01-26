import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  ClaimedLendingStabl3,
  Stabl3StakingOwnershipTransferred,
  Stake,
  Unstake,
  Stabl3StakingUpdatedHQ,
  Stabl3StakingUpdatedPermission,
  Stabl3StakingUpdatedROI,
  Stabl3StakingUpdatedTreasury,
  WithdrewReward
} from "../generated/Stabl3Staking/Stabl3Staking"

export function createClaimedLendingStabl3Event(
  user: Address,
  index: BigInt,
  token: Address,
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

export function createStabl3StakingOwnershipTransferredEvent(
  previousOwner: Address,
  newOwner: Address
): Stabl3StakingOwnershipTransferred {
  let stabl3StakingOwnershipTransferredEvent = changetype<
    Stabl3StakingOwnershipTransferred
  >(newMockEvent())

  stabl3StakingOwnershipTransferredEvent.parameters = new Array()

  stabl3StakingOwnershipTransferredEvent.parameters.push(
    new ethereum.EventParam(
      "previousOwner",
      ethereum.Value.fromAddress(previousOwner)
    )
  )
  stabl3StakingOwnershipTransferredEvent.parameters.push(
    new ethereum.EventParam("newOwner", ethereum.Value.fromAddress(newOwner))
  )

  return stabl3StakingOwnershipTransferredEvent
}

export function createStakeEvent(
  user: Address,
  index: BigInt,
  status: boolean,
  stakingType: i32,
  token: Address,
  amountToken: BigInt,
  totalAmountToken: BigInt,
  endTime: BigInt,
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
    new ethereum.EventParam("status", ethereum.Value.fromBoolean(status))
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
    new ethereum.EventParam(
      "endTime",
      ethereum.Value.fromUnsignedBigInt(endTime)
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

export function createStabl3StakingUpdatedHQEvent(
  newHQ: Address,
  oldHQ: Address
): Stabl3StakingUpdatedHQ {
  let stabl3StakingUpdatedHqEvent = changetype<Stabl3StakingUpdatedHQ>(
    newMockEvent()
  )

  stabl3StakingUpdatedHqEvent.parameters = new Array()

  stabl3StakingUpdatedHqEvent.parameters.push(
    new ethereum.EventParam("newHQ", ethereum.Value.fromAddress(newHQ))
  )
  stabl3StakingUpdatedHqEvent.parameters.push(
    new ethereum.EventParam("oldHQ", ethereum.Value.fromAddress(oldHQ))
  )

  return stabl3StakingUpdatedHqEvent
}

export function createStabl3StakingUpdatedPermissionEvent(
  contractAddress: Address,
  state: boolean
): Stabl3StakingUpdatedPermission {
  let stabl3StakingUpdatedPermissionEvent = changetype<
    Stabl3StakingUpdatedPermission
  >(newMockEvent())

  stabl3StakingUpdatedPermissionEvent.parameters = new Array()

  stabl3StakingUpdatedPermissionEvent.parameters.push(
    new ethereum.EventParam(
      "contractAddress",
      ethereum.Value.fromAddress(contractAddress)
    )
  )
  stabl3StakingUpdatedPermissionEvent.parameters.push(
    new ethereum.EventParam("state", ethereum.Value.fromBoolean(state))
  )

  return stabl3StakingUpdatedPermissionEvent
}

export function createStabl3StakingUpdatedROIEvent(
  newROI: Address,
  oldROI: Address
): Stabl3StakingUpdatedROI {
  let stabl3StakingUpdatedRoiEvent = changetype<Stabl3StakingUpdatedROI>(
    newMockEvent()
  )

  stabl3StakingUpdatedRoiEvent.parameters = new Array()

  stabl3StakingUpdatedRoiEvent.parameters.push(
    new ethereum.EventParam("newROI", ethereum.Value.fromAddress(newROI))
  )
  stabl3StakingUpdatedRoiEvent.parameters.push(
    new ethereum.EventParam("oldROI", ethereum.Value.fromAddress(oldROI))
  )

  return stabl3StakingUpdatedRoiEvent
}

export function createStabl3StakingUpdatedTreasuryEvent(
  newTreasury: Address,
  oldTreasury: Address
): Stabl3StakingUpdatedTreasury {
  let stabl3StakingUpdatedTreasuryEvent = changetype<
    Stabl3StakingUpdatedTreasury
  >(newMockEvent())

  stabl3StakingUpdatedTreasuryEvent.parameters = new Array()

  stabl3StakingUpdatedTreasuryEvent.parameters.push(
    new ethereum.EventParam(
      "newTreasury",
      ethereum.Value.fromAddress(newTreasury)
    )
  )
  stabl3StakingUpdatedTreasuryEvent.parameters.push(
    new ethereum.EventParam(
      "oldTreasury",
      ethereum.Value.fromAddress(oldTreasury)
    )
  )

  return stabl3StakingUpdatedTreasuryEvent
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
