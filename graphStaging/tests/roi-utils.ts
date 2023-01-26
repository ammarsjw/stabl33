import { newMockEvent } from "matchstick-as"
import { ethereum, BigInt, Address } from "@graphprotocol/graph-ts"
import {
  APR,
  ROIOwnershipTransferred,
  ROIUpdatedPermission,
  UpdatedTreasury
} from "../generated/ROI/ROI"

export function createAPREvent(
  APR: BigInt,
  reserves: BigInt,
  totalRewardDistributed: BigInt,
  timestamp: BigInt
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
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )

  return aprEvent
}

export function createROIOwnershipTransferredEvent(
  previousOwner: Address,
  newOwner: Address
): ROIOwnershipTransferred {
  let roiOwnershipTransferredEvent = changetype<ROIOwnershipTransferred>(
    newMockEvent()
  )

  roiOwnershipTransferredEvent.parameters = new Array()

  roiOwnershipTransferredEvent.parameters.push(
    new ethereum.EventParam(
      "previousOwner",
      ethereum.Value.fromAddress(previousOwner)
    )
  )
  roiOwnershipTransferredEvent.parameters.push(
    new ethereum.EventParam("newOwner", ethereum.Value.fromAddress(newOwner))
  )

  return roiOwnershipTransferredEvent
}

export function createROIUpdatedPermissionEvent(
  contractAddress: Address,
  state: boolean
): ROIUpdatedPermission {
  let roiUpdatedPermissionEvent = changetype<ROIUpdatedPermission>(
    newMockEvent()
  )

  roiUpdatedPermissionEvent.parameters = new Array()

  roiUpdatedPermissionEvent.parameters.push(
    new ethereum.EventParam(
      "contractAddress",
      ethereum.Value.fromAddress(contractAddress)
    )
  )
  roiUpdatedPermissionEvent.parameters.push(
    new ethereum.EventParam("state", ethereum.Value.fromBoolean(state))
  )

  return roiUpdatedPermissionEvent
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
