# Test Cases: MedicineRegistry

Run with `npx hardhat test` (Hardhat local network, Solidity 0.8.24). Full output: `docs/test-output.txt`.
**Result: 22 passing, 0 failing.**

| ID | Test case | Expected outcome | Actual result |
|----|-----------|------------------|---------------|
| T1 | Deploy with a regulator address | Regulator holds `REGULATOR_ROLE` | Pass |
| T2 | Deploy with the zero address | Reverts `ZeroAddress` | Pass |
| T3 | Regulator approves a manufacturer | `ManufacturerApproved` emitted, role and name stored | Pass |
| T4 | Non-regulator approves a manufacturer | Reverts `AccessControlUnauthorizedAccount` | Pass |
| T5 | Approve the same manufacturer twice | Reverts `AlreadyApproved` | Pass |
| T6 | Regulator removes a manufacturer, who then tries to register | `ManufacturerRemoved` emitted; registration reverts | Pass |
| T7 | Remove an address that is not a manufacturer | Reverts `NotApproved` | Pass |
| T8 | Approved manufacturer registers a batch | `BatchRegistered` emitted, `totalBatches` = 1 | Pass |
| T9 | Unapproved address registers a batch | Reverts `AccessControlUnauthorizedAccount` | Pass |
| T10 | Register a duplicate batch ID | Reverts `BatchAlreadyExists` | Pass |
| T11 | Register with an expiry date in the past | Reverts `ExpiryNotInFuture` | Pass |
| T12 | Register with an empty batch ID or drug name | Reverts `EmptyInput` | Pass |
| T13 | Verify a registered batch | Status `Genuine`, correct drug, manufacturer and name | Pass |
| T14 | Verify an unknown batch ID | Status `NotFound` | Pass |
| T15 | Verify a batch after its expiry date | Status `Expired` | Pass |
| T16 | Verify from an account with no role | Works, status `Genuine` | Pass |
| T17 | Regulator recalls a batch | `BatchRecalled` emitted; status `Recalled` with reason | Pass |
| T18 | Manufacturer tries to recall | Reverts `AccessControlUnauthorizedAccount` | Pass |
| T19 | Recall an unknown batch | Reverts `BatchDoesNotExist` | Pass |
| T20 | Recall with empty reason / recall twice | Reverts `EmptyInput` / `AlreadyRecalled` | Pass |
| T21 | Recalled batch passes its expiry date | Still `Recalled` (recall takes priority) | Pass |
| T22 | Regulator adds another regulator; stranger tries | Allowed / reverts `AccessControlUnauthorizedAccount` | Pass |

## Sepolia interaction tests (manual, via Remix)

| Step | Account | Call | Expected | Actual |
|------|---------|------|----------|--------|
| S1 | Regulator | `approveManufacturer(manufacturer, "PharmaCo Ltd")` | Success | Pass. Mined in block 12175015, tx `0x5a7ceecbeff5a966432f692f0671520d717dc4ff2f6bca95fbffba05c176e4a8` ([S1](screenshots/S1.png)) |
| S2 | Manufacturer | `registerBatch("PARA-2026-001", "Paracetamol 500mg", 1830000000)` | Success | Pass. Mined in block 12175099, `BatchRegistered` event emitted ([S2](screenshots/S2.png)) |
| S3 | Anyone | `verifyBatch("PARA-2026-001")` | status 1 (Genuine) | Pass. status 1 (Genuine), manufacturer label "PharmaCo Ltd" ([S3](screenshots/S3.png)) |
| S4 | Anyone | `verifyBatch("FAKE-999")` | status 0 (NotFound) | Pass. status 0 (NotFound), empty record ([S4](screenshots/S4.png)) |
| S5 | Regulator | `recallBatch("PARA-2026-001", "Contamination found")` | Success | Pass. Mined in block 12175163, `BatchRecalled` event emitted ([S5](screenshots/S5.png)) |
| S6 | Anyone | `verifyBatch("PARA-2026-001")` | status 3 (Recalled) | Pass. status 3 (Recalled), reason "Contamination found" ([S6](screenshots/S6.png)) |
| S7 | Manufacturer | `recallBatch(...)` | Reverts (access control) | Pass. Transaction reverted (block 12175145), batch not recalled ([S7](screenshots/S7.png)) |

Status values: 0 NotFound, 1 Genuine, 2 Expired, 3 Recalled. Screenshots for S1 to S7 are in `docs/screenshots/` (`S1.png` to `S7.png`).

## Demo page tests (manual, in the browser)

These tests used `frontend/index.html` against the same Sepolia contract.

| Step | Account | Action | Expected | Actual |
|------|---------|--------|----------|--------|
| D1 | Manufacturer | Register batch `AMOX-2026-001`, Amoxicillin 500mg | Confirmation message | Pass, "Batch AMOX-2026-001 is now registered" ([demo-1-register.png](screenshots/demo-1-register.png)) |
| D2 | None (read-only) | Check `AMOX-2026-001` | Genuine, with medicine and manufacturer | Pass, green Genuine card, PharmaCo Ltd ([demo-2-genuine.png](screenshots/demo-2-genuine.png)) |
| D3 | Regulator | Recall `AMOX-2026-001`, reason "contamination" | Confirmation message | Pass, "has been recalled" ([demo-3-recall.png](screenshots/demo-3-recall.png)) |
| D4 | None (read-only) | Check `AMOX-2026-001` again | Recalled, with the reason | Pass, red Recalled card with the reason ([demo-4-recalled.png](screenshots/demo-4-recalled.png)) |
| D5 | Manufacturer | Try to recall a batch | Refused with a clear message | Pass, "This wallet is not a regulator, so it cannot recall batches." |

