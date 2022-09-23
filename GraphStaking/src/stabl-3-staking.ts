import { Bytes, BigInt } from "@graphprotocol/graph-ts"

import {
  ClaimedLendingStabl3 as ClaimedLendingStabl3Event,
  Stake as StakeEvent,
  Unstake as UnstakeEvent,
  UpdatedHQ as UpdatedHQEvent,
  UpdatedLendingStabl3ClaimTime as UpdatedLendingStabl3ClaimTimeEvent,
  UpdatedLendingStabl3Percentage as UpdatedLendingStabl3PercentageEvent,
  UpdatedLockTime as UpdatedLockTimeEvent,
  UpdatedPermission as UpdatedPermissionEvent,
  UpdatedROI as UpdatedROIEvent,
  UpdatedTreasury as UpdatedTreasuryEvent,
  UpdatedUnstakeFeePercentage as UpdatedUnstakeFeePercentageEvent,
  WithdrewReward as WithdrewRewardEvent
} from "../generated/Stabl3Staking/Stabl3Staking"

import {
  ClaimedLendingStabl3,
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
} from "../generated/schema"

import { loadOrCreateTransaction } from "./utils/Transactions"

export function handleClaimedLendingStabl3(event: ClaimedLendingStabl3Event): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new ClaimedLendingStabl3(transaction.id)
  entity.transaction = transaction.id
  entity.user = event.params.user
  entity.index = event.params.index
  entity.token = event.params.token
  entity.amountTokenLending = event.params.amountTokenLending
  entity.amountStabl3Lending = event.params.amountStabl3Lending
  entity.totalAmountStabl3Withdrawn = event.params.totalAmountStabl3Withdrawn
  entity.timestamp = event.params.timestamp
  entity.save()
}

export function handleStake(event: StakeEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let id = event.params.user.toHexString().concat("-").concat(event.params.index.toString());
  let entity = new Stake(id)
  entity.transaction = transaction.id
  entity.user = event.params.user
  entity.index = event.params.index
  entity.stakingType = event.params.stakingType
  entity.token = event.params.token
  entity.amountToken = event.params.amountToken
  entity.totalAmountToken = event.params.totalAmountToken
  entity.isLend = event.params.isLend
  entity.timestamp = event.params.timestamp
  entity.save()
}

export function handleUnstake(event: UnstakeEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new Unstake(transaction.id)
  entity.transaction = transaction.id
  entity.user = event.params.user
  entity.index = event.params.index
  entity.token = event.params.token
  entity.amountToken = event.params.amountToken
  entity.reward = event.params.reward
  entity.stakingType = event.params.stakingType
  entity.isLend = event.params.isLend
  entity.save()
}

export function handleUpdatedHQ(event: UpdatedHQEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedHQ(transaction.id)
  entity.transaction = transaction.id
  entity.newHQ = event.params.newHQ
  entity.oldHQ = event.params.oldHQ
  entity.save()
}

export function handleUpdatedLendingStabl3ClaimTime(event: UpdatedLendingStabl3ClaimTimeEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedLendingStabl3ClaimTime(transaction.id)
  entity.transaction = transaction.id
  entity.newLendingStabl3ClaimTime = event.params.newLendingStabl3ClaimTime
  entity.oldLendingStabl3ClaimTime = event.params.oldLendingStabl3ClaimTime
  entity.save()
}

export function handleUpdatedLendingStabl3Percentage(event: UpdatedLendingStabl3PercentageEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedLendingStabl3Percentage(transaction.id)
  entity.transaction = transaction.id
  entity.newLendingStabl3Percentage = event.params.newLendingStabl3Percentage
  entity.oldLendingStabl3Percentage = event.params.oldLendingStabl3Percentage
  entity.save()
}

export function handleUpdatedLockTime(event: UpdatedLockTimeEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedLockTime(transaction.id)
  entity.transaction = transaction.id
  entity.newLockTimes = event.params.newLockTimes
  entity.oldLockTimes = event.params.oldLockTimes
  entity.save()
}

export function handleUpdatedPermission(event: UpdatedPermissionEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedPermission(transaction.id)
  entity.transaction = transaction.id
  entity.contractAddress = event.params.contractAddress
  entity.state = event.params.state
  entity.save()
}

export function handleUpdatedROI(event: UpdatedROIEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedROI(transaction.id)
  entity.transaction = transaction.id
  entity.newROI = event.params.newROI
  entity.oldROI = event.params.oldROI
  entity.save()
}

export function handleUpdatedTreasury(event: UpdatedTreasuryEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedTreasury(transaction.id)
  entity.transaction = transaction.id
  entity.newTreasury = event.params.newTreasury
  entity.oldTreasury = event.params.oldTreasury
  entity.save()
}

export function handleUpdatedUnstakeFeePercentage(event: UpdatedUnstakeFeePercentageEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedUnstakeFeePercentage(transaction.id)
  entity.transaction = transaction.id
  entity.newUnstakeFeePercentage = event.params.newUnstakeFeePercentage
  entity.oldUnstakeFeePercentage = event.params.oldUnstakeFeePercentage
  entity.save()
}

export function handleWithdrewReward(event: WithdrewRewardEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new WithdrewReward(transaction.id)
  entity.transaction = transaction.id
  entity.user = event.params.user
  entity.index = event.params.index
  entity.token = event.params.token
  entity.rewardWithdrawn = event.params.rewardWithdrawn
  entity.totalRewardWithdrawn = event.params.totalRewardWithdrawn
  entity.isLend = event.params.isLend
  entity.timestamp = event.params.timestamp
  entity.save()
}
