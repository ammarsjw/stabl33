import { Bytes, BigInt } from "@graphprotocol/graph-ts"

import {
  ClaimedLendingStabl3 as ClaimedLendingStabl3Event,
  OwnershipTransferred as OwnershipTransferredEvent,
  Stake as StakeEvent,
  Unstake as UnstakeEvent,
  UpdatedHQ as UpdatedHQEvent,
  UpdatedROI as UpdatedROIEvent,
  UpdatedTreasury as UpdatedTreasuryEvent,
  WithdrewReward as WithdrewRewardEvent
} from "../generated/Stabl3Staking/Stabl3Staking"

import {
  ClaimedLendingStabl3,
  OwnershipTransferred,
  Stake,
  Unstake,
  UpdatedHQ,
  UpdatedROI,
  UpdatedTreasury,
  WithdrewReward
} from "../generated/schema"

import { loadOrCreateTransaction } from "./utils/Transactions"

export function handleOwnershipTransferred(event: OwnershipTransferredEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let entity = new OwnershipTransferred(transaction.id)
  entity.transaction = transaction.id
  entity.previousOwner = event.params.previousOwner
  entity.newOwner = event.params.newOwner
  entity.save()
}

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
  entity.status = event.params.status
  entity.stakingType = event.params.stakingType
  entity.token = event.params.token
  entity.amountToken = event.params.amountToken
  entity.totalAmountToken = event.params.totalAmountToken
  entity.endTime = event.params.endTime
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

  let id = event.params.user.toHexString().concat("-").concat(event.params.index.toString());
  let entityToUpdate = Stake.load(id);
  if (entityToUpdate) {
    entityToUpdate.status = false
    entityToUpdate.save()
  }
}

export function handleUpdatedHQ(event: UpdatedHQEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedHQ(transaction.id)
  entity.transaction = transaction.id
  entity.newHQ = event.params.newHQ
  entity.oldHQ = event.params.oldHQ
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