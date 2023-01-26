import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  OwnershipTransferred,
  Rate,
  UpdatedExchangeFee,
  UpdatedHQ,
  UpdatedPermission,
  UpdatedROI,
  UpdatedReservedToken
} from "../generated/Treasury/Treasury"

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

export function createRateEvent(
  rate: BigInt,
  reserves: BigInt,
  totalValueLocked: BigInt,
  stabl3CirculatingSupply: BigInt,
  timestamp: BigInt
): Rate {
  let rateEvent = changetype<Rate>(newMockEvent())

  rateEvent.parameters = new Array()

  rateEvent.parameters.push(
    new ethereum.EventParam("rate", ethereum.Value.fromUnsignedBigInt(rate))
  )
  rateEvent.parameters.push(
    new ethereum.EventParam(
      "reserves",
      ethereum.Value.fromUnsignedBigInt(reserves)
    )
  )
  rateEvent.parameters.push(
    new ethereum.EventParam(
      "totalValueLocked",
      ethereum.Value.fromUnsignedBigInt(totalValueLocked)
    )
  )
  rateEvent.parameters.push(
    new ethereum.EventParam(
      "stabl3CirculatingSupply",
      ethereum.Value.fromUnsignedBigInt(stabl3CirculatingSupply)
    )
  )
  rateEvent.parameters.push(
    new ethereum.EventParam(
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )

  return rateEvent
}

export function createUpdatedExchangeFeeEvent(
  newExchangeFee: BigInt,
  oldExchangeFee: BigInt
): UpdatedExchangeFee {
  let updatedExchangeFeeEvent = changetype<UpdatedExchangeFee>(newMockEvent())

  updatedExchangeFeeEvent.parameters = new Array()

  updatedExchangeFeeEvent.parameters.push(
    new ethereum.EventParam(
      "newExchangeFee",
      ethereum.Value.fromUnsignedBigInt(newExchangeFee)
    )
  )
  updatedExchangeFeeEvent.parameters.push(
    new ethereum.EventParam(
      "oldExchangeFee",
      ethereum.Value.fromUnsignedBigInt(oldExchangeFee)
    )
  )

  return updatedExchangeFeeEvent
}

export function createUpdatedHQEvent(
  newHQ: Address,
  oldHQ: Address
): UpdatedHQ {
  let updatedHqEvent = changetype<UpdatedHQ>(newMockEvent())

  updatedHqEvent.parameters = new Array()

  updatedHqEvent.parameters.push(
    new ethereum.EventParam("newHQ", ethereum.Value.fromAddress(newHQ))
  )
  updatedHqEvent.parameters.push(
    new ethereum.EventParam("oldHQ", ethereum.Value.fromAddress(oldHQ))
  )

  return updatedHqEvent
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

export function createUpdatedROIEvent(
  newROI: Address,
  oldROI: Address
): UpdatedROI {
  let updatedRoiEvent = changetype<UpdatedROI>(newMockEvent())

  updatedRoiEvent.parameters = new Array()

  updatedRoiEvent.parameters.push(
    new ethereum.EventParam("newROI", ethereum.Value.fromAddress(newROI))
  )
  updatedRoiEvent.parameters.push(
    new ethereum.EventParam("oldROI", ethereum.Value.fromAddress(oldROI))
  )

  return updatedRoiEvent
}

export function createUpdatedReservedTokenEvent(
  token: Address,
  state: boolean
): UpdatedReservedToken {
  let updatedReservedTokenEvent = changetype<UpdatedReservedToken>(
    newMockEvent()
  )

  updatedReservedTokenEvent.parameters = new Array()

  updatedReservedTokenEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )
  updatedReservedTokenEvent.parameters.push(
    new ethereum.EventParam("state", ethereum.Value.fromBoolean(state))
  )

  return updatedReservedTokenEvent
}
