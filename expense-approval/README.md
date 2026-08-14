# Expense approval — durable workflow with two human tasks

A plain durable workflow with **two manager reviews**, both decided in the ICP
task inbox:

1. `checkExpenseRequest` — triage the new claim: request the supporting bills,
   or reject it.
2. After the employee submits the bills (a `billSubmitted` **data event**), the
   workflow validates them (`validateBills`: at least one bill, billed total
   matches the claim) and creates `reviewBills` — approve to reimburse, or
   reject.

On approval the workflow pays the claim and notifies the employee — and both
activities demo the retry policies:

- `makePayment` (not gated) runs with a **Human Review** retry policy
  (`retryPolicy = "manager"`): the mock gateway rejects payments in **USD or
  LKR**, and instead of failing the workflow the error becomes a retry review
  task in the ICP inbox where a manager can fix the inputs and re-run.
- `notifyEmployee` runs with an **Auto Retry** policy (`{maxRetries: 3}`): the
  mock notification service fails every other call, and the engine retries it
  transparently.

The workflow durably suspends on each task and on the bill submission for as
long as they take, surviving restarts. Human tasks are completed through the
ICP UI — the service exposes no task-completion API.

## Run

```sh
temporal server start-dev   # in another terminal
cp Config.toml.back Config.toml   # fill in the ICP runtime secret
bal run
```

```sh
# 1. Submit a claim (starts the workflow); note the workflowId in the response —
#    it is the claim reference in the calls below
curl -X POST localhost:9096/expenses -H 'Content-Type: application/json' \
  -d '{"claimId":"EXP-1","employee":"nimal","amount":180.50,"currency":"EUR","purpose":"Team lunch"}'

# 2. In the ICP task inbox (role: manager, e.g. alice), decide checkExpenseRequest:
#    choose action REQUEST_BILL (or REJECT to end the claim)

# 3. Submit the supporting bills (delivered to the waiting workflow as a data event)
curl -X POST localhost:9096/expenses/<workflowId>/bills -H 'Content-Type: application/json' \
  -d '{"bills":[{"reference":"BILL-9","amount":180.50}]}'

# 4. In the ICP task inbox, decide reviewBills: approve to reimburse, or reject

# 5. Read the outcome (IN_REVIEW while a task or the bills are pending)
curl localhost:9096/expenses/<workflowId>
```

To see the **Human Review retry**, submit a claim with `"currency":"USD"` (or
`LKR`) and approve it: the payment fails, and a retry review task appears in the
ICP inbox where the manager can correct the currency and retry. The **Auto
Retry** shows up in the service log — every other `notifyEmployee` call fails
and is retried by the engine.

## Scenario scripts

Ready-made request sequences in [`tryit/`](tryit/) (same format as the generated
`target/TryIt.hurl`). Run them with [hurl](https://hurl.dev) in interactive mode
so you can decide the ICP inbox tasks between steps:

```sh
hurl --interactive tryit/scenario-1-happy-path.hurl
```

| Scenario | Shows |
|---|---|
| [1 — happy path](tryit/scenario-1-happy-path.hurl) | Both tasks approved, claim paid |
| [2 — reject at triage](tryit/scenario-2-reject-at-triage.hurl) | Manager rejects `checkExpenseRequest` |
| [3 — mismatched bills](tryit/scenario-3-mismatched-bills.hurl) | `reviewBills` payload flags `billsMatchClaim: false` |
| [4 — payment retry (USD)](tryit/scenario-4-payment-retry-usd.hurl) | Human Review retry: fix the currency in the ICP inbox |
| [5 — invalid claim](tryit/scenario-5-invalid-claim.hurl) | Fails validation, no human task |

## Requirements

- `ballerina/workflow` **0.8.3** and `wso2/icp.runtime.bridge` **0.2.0**, resolved from Ballerina Central.
- Temporal dev server on `localhost:7233`.
- ICP running with a `manager`-role user (see the repository README).
