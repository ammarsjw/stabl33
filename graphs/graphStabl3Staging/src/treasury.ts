import { Bytes, BigInt } from "@graphprotocol/graph-ts"

import {
  Rate as RateEvent,
  UpdatedReservedToken as UpdatedReservedTokenEvent
} from "../generated/Treasury/Treasury"

import {
  Rate,
  UpdatedReservedToken
} from "../generated/schema"

import { loadOrCreateTransaction } from "./utils/Transactions"

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
  let id = transaction.id.concat("-").concat(event.params.rate.toString()).concat("-").concat(event.params.totalValueLocked.toString()).concat("-").concat(event.params.reserves.toString()).concat("-").concat(event.params.stabl3CirculatingSupply.toString()).concat("-").concat(event.params.timestamp.toString());
  let entity = new Rate(id)
  entity.transaction = transaction.id
  entity.rate = event.params.rate
  entity.reserves = event.params.reserves
  entity.totalValueLocked = event.params.totalValueLocked
  entity.stabl3CirculatingSupply = event.params.stabl3CirculatingSupply
  entity.timestamp = event.params.timestamp
  entity.save()
}