import { Bytes, BigInt } from "@graphprotocol/graph-ts"

import {
  APR as APREvent,
  OwnershipTransferred as OwnershipTransferredEvent,
  UpdatedPermission as UpdatedPermissionEvent,
  UpdatedTreasury as UpdatedTreasuryEvent
} from "../generated/ROI/ROI"

import {
  APR,
  OwnershipTransferred,
  UpdatedPermission,
  UpdatedTreasury
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

export function handleAPR(event: APREvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = transaction.id.concat("-").concat(event.params.APR.toString()).concat("-").concat(event.params.reserves.toString()).concat("-").concat(event.params.totalRewardDistributed.toString()).concat("-").concat(event.params.blockTimestampLast.toString());
  let entity = new APR(id)
  entity.transaction = transaction.id
  entity.APR = event.params.APR
  entity.reserves = event.params.reserves
  entity.totalRewardDistributed = event.params.totalRewardDistributed
  entity.timestamp = event.params.timestamp
  entity.save()
}

export function handleUpdatedPermission(event: UpdatedPermissionEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let entity = new UpdatedPermission(transaction.id)
  entity.transaction = transaction.id
  entity.contractAddress = event.params.contractAddress
  entity.state = event.params.state
  entity.save()
}

export function handleUpdatedTreasury(event: UpdatedTreasuryEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let entity = new UpdatedTreasury(transaction.id)
  entity.transaction = transaction.id
  entity.newTreasury = event.params.newTreasury
  entity.oldTreasury = event.params.oldTreasury
  entity.save()
}
