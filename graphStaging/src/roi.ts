import { Bytes, BigInt } from "@graphprotocol/graph-ts"

import {
  APR as APREvent
} from "../generated/ROI/ROI"

import {
  APR
} from "../generated/schema"

import { loadOrCreateTransaction } from "./utils/Transactions"

export function handleAPR(event: APREvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = transaction.id.concat("-").concat(event.params.APR.toString()).concat("-").concat(event.params.reserves.toString()).concat("-").concat(event.params.totalRewardDistributed.toString()).concat("-").concat(event.params.timestamp.toString());
  let entity = new APR(id)
  entity.transaction = transaction.id
  entity.APR = event.params.APR
  entity.reserves = event.params.reserves
  entity.totalRewardDistributed = event.params.totalRewardDistributed
  entity.timestamp = event.params.timestamp
  entity.save()
}