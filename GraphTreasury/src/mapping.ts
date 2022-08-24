import { Bytes, BigInt } from "@graphprotocol/graph-ts"

import {
  OwnershipTransferred as OwnershipTransferredEvent,
  Rate as RateEvent,
  UpdatedPermission as UpdatedPermissionEvent,
  UpdatedReservedToken as UpdatedReservedTokenEvent 
} from "../generated/Treasury/Treasury"

import {
  OwnershipTransferred,
  Rate,
  UpdatedPermission,
  UpdatedReservedToken
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

export function handleUpdatedPermission(event: UpdatedPermissionEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let entity = new UpdatedPermission(transaction.id)
  entity.transaction = transaction.id
  entity.contractAddress = event.params.contractAddress
  entity.state = event.params.state
  entity.save()
}

export function handleUpdatedReservedToken(event: UpdatedReservedTokenEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let entity = new UpdatedReservedToken(transaction.id)
  entity.transaction = transaction.id
  entity.token = event.params.token
  entity.state = event.params.state
  entity.save()
}

export function handleRate(event: RateEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let entity = new Rate(event.params.blockTimestampLast.toString())
  entity.transaction = transaction.id
  entity.rate = event.params.rate
  entity.blockTimestampLast = event.params.blockTimestampLast
  entity.save()
}