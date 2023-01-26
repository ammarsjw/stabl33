import { newMockEvent } from "matchstick-as"
import { ethereum, BigInt, Address } from "@graphprotocol/graph-ts"
import {
  APR,
  OwnershipTransferred,
  UpdatedPermission,
  UpdatedTreasury
} from "../generated/ROI/ROI"

export function createAPREvent(
  APR: BigInt,
  reserves: BigInt,
  totalRewardDistributed: BigInt,
  blockTimestampLast: BigInt
): APR {
  let aprEvent = changetype<APR>(newMockEvent())

  aprEvent.parameters = new Array()

  aprEvent.parameters.push(
    new ethereum.EventParam("APR", ethereum.Value.fromUnsignedBigInt(APR))
  )
  aprEvent.parameters.push(
    new ethereum.EventParam(
      "reserves",
      ethereum.Value.fromUnsignedBigInt(reserves)
    )
  )
  aprEvent.parameters.push(
    new ethereum.EventParam(
      "totalRewardDistributed",
      ethereum.Value.fromUnsignedBigInt(totalRewardDistributed)
    )
  )
  aprEvent.parameters.push(
    new ethereum.EventParam(
      "blockTimestampLast",
      ethereum.Value.fromUnsignedBigInt(blockTimestampLast)
    )
  )

  return aprEvent
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
