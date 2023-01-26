import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Address, BigInt } from "@graphprotocol/graph-ts"
import { ClaimedLendingStabl3 } from "../generated/schema"
import { ClaimedLendingStabl3 as ClaimedLendingStabl3Event } from "../generated/Stabl3Staking/Stabl3Staking"
import { handleClaimedLendingStabl3 } from "../src/stabl-3-staking"
import { createClaimedLendingStabl3Event } from "./stabl-3-staking-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let user = Address.fromString("0x0000000000000000000000000000000000000001")
    let index = BigInt.fromI32(234)
    let token = Address.fromString("0x0000000000000000000000000000000000000001")
    let amountStabl3Lending = BigInt.fromI32(234)
    let totalAmountStabl3Withdrawn = BigInt.fromI32(234)
    let timestamp = BigInt.fromI32(234)
    let newClaimedLendingStabl3Event = createClaimedLendingStabl3Event(
      user,
      index,
      token,
      amountStabl3Lending,
      totalAmountStabl3Withdrawn,
      timestamp
    )
    handleClaimedLendingStabl3(newClaimedLendingStabl3Event)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("ClaimedLendingStabl3 created and stored", () => {
    assert.entityCount("ClaimedLendingStabl3", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "ClaimedLendingStabl3",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "user",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "ClaimedLendingStabl3",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "index",
      "234"
    )
    assert.fieldEquals(
      "ClaimedLendingStabl3",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "token",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "ClaimedLendingStabl3",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "amountStabl3Lending",
      "234"
    )
    assert.fieldEquals(
      "ClaimedLendingStabl3",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "totalAmountStabl3Withdrawn",
      "234"
    )
    assert.fieldEquals(
      "ClaimedLendingStabl3",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "timestamp",
      "234"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
