# Loan approval — child-workflow composition

A loan application processed as a **parent workflow composing four durable child
workflows**:

| Child | Pattern shown |
| --- | --- |
| `kycWorkflow` + `creditScoreWorkflow` | Fan-out with `ctx->runChildWorkflow`, fan-in with `ctx->waitForChildWorkflow` |
| `disbursementWorkflow` | A child that durably **waits for a data event** the parent sends with `ctx->sendDataToChildWorkflow` |
| `notificationWorkflow` | Synchronous call-and-wait with `ctx->callWorkflow` |

Children are true Temporal child workflows: their lifecycle is tied to the
parent, and every wait suspends durably (no thread held, crash-resumable).

## Run

```sh
temporal server start-dev   # in another terminal
bal run
```

Expected output ends with an approved decision carrying the disbursement
transfer reference.

## Requirements

- `ballerina/workflow` **0.8.3**, resolved from Ballerina Central.
- A local Temporal dev server on `localhost:7233` (see `Config.toml`).
