import { Bytes, BigInt } from "@graphprotocol/graph-ts"

import {
  CreatedBond as CreatedBondEvent,
  Bond as BondEvent,
  ClaimedBond as ClaimedBondEvent
} from "../generated/Stabl3Bonding/Stabl3Bonding"

import {
  CreatedBond,
  Bond,
  ClaimedBond
} from "../generated/schema"

import { loadOrCreateTransaction } from "./utils/Transactions"

export function handleCreatedBond(event: CreatedBondEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new CreatedBond(transaction.id)
  entity.transaction = transaction.id
  entity.bondIndex = event.params.bondIndex
  entity.bondAmount = event.params.bondAmount
  entity.discount = event.params.discount
  entity.startTime = event.params.startTime
  entity.expiryTime = event.params.expiryTime
  entity.save()
}

export function handleBond(event: BondEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let id = event.params.bondIndex.toString().concat("-").concat(event.params.user.toHexString()).concat("-").concat(event.params.index.toString())
  let entity = new Bond(id)
  entity.transaction = transaction.id
  entity.user = event.params.user
  entity.index = event.params.index
  entity.bondIndex = event.params.bondIndex
  entity.status = false
  entity.amountStabl3 = event.params.amountStabl3
  entity.token = event.params.token
  entity.amountToken = event.params.amountToken
  entity.totalAmountToken = event.params.totalAmountToken
  entity.timestamp = event.params.timestamp
  entity.save()
}

export function handleClaimedBond(event: ClaimedBondEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let id = event.params.bondIndex.toString().concat("-").concat(event.params.user.toHexString()).concat("-").concat(event.params.index.toString())
  let entity = new ClaimedBond(id)
  entity.transaction = transaction.id
  entity.user = event.params.user
  entity.index = event.params.index
  entity.bondIndex = event.params.bondIndex
  entity.amountStabl3 = event.params.amountStabl3
  entity.token = event.params.token
  entity.amountToken = event.params.amountToken
  entity.totalAmountStabl3 = event.params.totalAmountStabl3
  entity.timestamp = event.params.timestamp
  entity.save()

  let entityToUpdate = Bond.load(id)
  if (entityToUpdate) {
    entityToUpdate.status = true
    entityToUpdate.save()
  }
}