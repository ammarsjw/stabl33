import { Bytes, BigInt } from "@graphprotocol/graph-ts"

import {
  Borrow as BorrowEvent,
  Payback as PaybackEvent,
  ExchangeUCD as ExchangeUCDEvent
} from "../generated/Stabl3Borrowing/Stabl3Borrowing"

import {
  Borrow,
  Payback,
  ExchangeUCD
} from "../generated/schema"

import { loadOrCreateTransaction } from "./utils/Transactions"

export function handleBorrow(event: BorrowEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new Borrow(transaction.id)
  entity.transaction = transaction.id
  entity.user = event.params.user
  entity.amountUCD = event.params.amountUCD
  entity.amountStabl3 = event.params.amountStabl3
  entity.rate = event.params.rate
  entity.timestamp = event.params.timestamp
  entity.save()
}

export function handlePayback(event: PaybackEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new Payback(transaction.id)
  entity.transaction = transaction.id
  entity.user = event.params.user
  entity.amountUCD = event.params.amountUCD
  entity.amountStabl3 = event.params.amountStabl3
  entity.rate = event.params.rate
  entity.timestamp = event.params.timestamp
  entity.save()
}

export function handleExchangeUCD(event: ExchangeUCDEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new ExchangeUCD(transaction.id)
  entity.transaction = transaction.id
  entity.user = event.params.user
  entity.exchangingToken = event.params.exchangingToken
  entity.amountExchangingToken = event.params.amountExchangingToken
  entity.amountUCD = event.params.amountUCD
  entity.fee = event.params.fee
  entity.timestamp = event.params.timestamp
  entity.save()
}