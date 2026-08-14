# Expense approval agent — durable agentic workflow version

The same expense process as [`expense-approval`](../expense-approval/), driven by
a **durable agentic workflow** — and where the traditional workflow needs two
human tasks, the agent needs **one**:

- The agent first validates the claim and checks whether it already includes
  the supporting bills. If not, it calls the `requestBill` notification activity
  (a println stand-in) and waits for the bills on the `billSubmitted` event
  channel.
- When the bills arrive it validates them (`validateBills`: at least one bill,
  totals match) and only escalates to the single `approveExpense` human task
  when something needs a manager — mismatched totals, missing bills, or an
  unusually large amount. The gated `makePayment` keeps every payout behind a
  manager review regardless — and it carries a **Human Review** retry policy:
  the mock gateway rejects **USD or LKR** payments, turning the failure into a
  manager retry review instead of a failed run. `notifyEmployee` carries an
  **Auto Retry** policy and recovers from the mock notification service failing
  every other call.

Human tasks and reviews are decided in the ICP task inbox; the service exposes
no task-completion API.

## Run

```sh
temporal server start-dev   # in another terminal
cp Config.toml.back Config.toml   # fill in the ICP runtime secret + model provider
bal run
```

```sh
# 1. Submit a claim without bills (the agent will ask for them); note the
#    instanceId in the response — it is the claim reference in the calls below
curl -X POST localhost:9098/expenses -H 'Content-Type: application/json' \
  -d '{"claimId":"EXP-A1","employee":"nimal","amount":180.50,"currency":"EUR","purpose":"Team lunch"}'

# 2. Watch the service log: the agent's requestBill notification asks for the bills

# 3. Submit the bills (delivered on the agent's billSubmitted channel; the reply is
#    the agent's acknowledgement for this turn)
curl -X POST localhost:9098/expenses/<instanceId>/bills -H 'Content-Type: application/json' \
  -d '{"bills":[{"reference":"BILL-9","amount":180.50}]}'

# 4. If the agent escalates (or when the gated reimbursement review fires), decide
#    the approveExpense task in the ICP inbox (role: manager, e.g. alice)

# 5. Read the outcome (PENDING_APPROVAL while the manager decides)
curl localhost:9098/expenses/<instanceId>
```

Tip: submit mismatching bills (e.g. `"amount": 120.00`) to see the agent escalate
to the human task, or submit the claim with `"currency":"USD"` to see the payment
fail into a manager retry review after the gated approval.

## Scenario scripts

Ready-made request sequences in [`tryit/`](tryit/) (same format as the generated
`target/TryIt.hurl`). Run them with [hurl](https://hurl.dev) in interactive mode
so you can decide the ICP inbox reviews between steps:

```sh
hurl --interactive tryit/scenario-1-happy-path.hurl
```

| Scenario | Shows |
|---|---|
| [1 — happy path](tryit/scenario-1-happy-path.hurl) | Agent requests the missing bills, then completes |
| [2 — bills upfront](tryit/scenario-2-bills-upfront.hurl) | Agent skips the bill request entirely |
| [3 — mismatched bills](tryit/scenario-3-mismatched-bills-escalation.hurl) | Agent escalates to the `approveExpense` task |
| [4 — payment retry (USD)](tryit/scenario-4-payment-retry-usd.hurl) | Human Review retry after the gated approval |

## Requirements

- `ballerina/workflow` **0.8.3** and `wso2/icp.runtime.bridge` **0.2.0**, resolved from Ballerina Central.
- Temporal dev server on `localhost:7233`.
- WSO2 model provider credentials and the ICP runtime secret in `Config.toml`.
- ICP running with a `manager`-role user (see the repository README).
