# Durable workflow & agent examples

Real-world examples for the Ballerina `workflow` module: durable workflows with
child workflows, human tasks and data events, plus durable agentic workflows
(object-model agents with A2A peers). Open this folder — or
`workflow-examples.code-workspace` — in VS Code (WSO2 Integrator) to get all
packages as one workspace.

> The previous human-task UI example lives on the
> [`old-humantask-example`](../../tree/old-humantask-example) branch.

| Package | Scenario | What it demonstrates |
| --- | --- | --- |
| [`loan-approval`](loan-approval/) | Loan origination | **Child workflows**: fan-out/fan-in (`runChildWorkflow` / `waitForChildWorkflow`), data events to children (`sendDataToChildWorkflow`), synchronous composition (`callWorkflow`) |
| [`expense-approval`](expense-approval/) | Expense reimbursement | **Two human tasks + a data event**: request check, bill submission (`workflow:sendData`), bill review — all decided in the ICP inbox |
| [`expense-approval-agent`](expense-approval-agent/) | Expense reimbursement | **Agentic version of expense-approval**: one human task instead of two — the agent requests/validates bills itself and escalates only when needed |
| [`shipment-tracking`](shipment-tracking/) | Courier tracking | **Data events**: two `future` data events (`pickedUp`, `delivered`) driven by `workflow:sendData` callbacks |
| [`customer-support-agent`](customer-support-agent/) | Support triage | **Single durable agent**: activities, approval-gated refunds, AI tool, human-task escalation, multi-turn conversation channel |
| [`travel-desk-agents`](travel-desk-agents/) | Trip planning | **Multi-agent / A2A**: coordinator + two specialist peer agents, synchronous and asynchronous (callback channel) delegation |

## Prerequisite: the `workflow` module

These examples use the released
[`ballerina/workflow`](https://central.ballerina.io/ballerina/workflow) **0.8.3**
from Ballerina Central — no local build is needed. Every example's
`Ballerina.toml` pins the version; `bal build` pulls it (and
`wso2/icp.runtime.bridge` 0.2.0 for the expense examples) automatically.
The examples target distribution **2201.13.4** (Swan Lake Update 13).

> If you previously followed the local-build instructions from an older
> revision of this repo, remove the stale local copies so they cannot shadow
> the released packages: delete
> `~/.ballerina/repositories/local/bala/ballerina/workflow` and purge the
> extracted caches (`~/.ballerina/repositories/local/cache-*/ballerina/workflow`).

## Runtime setup

1. **Temporal** — all examples expect a dev server on `localhost:7233`:

   ```sh
   temporal server start-dev
   ```

2. **Configuration** — `Config.toml` is git-ignored because it carries secrets
   (the ICP runtime secret, model provider tokens). Each package commits a
   scrubbed `Config.toml.back`: copy it and fill in the placeholders:

   ```sh
   cp Config.toml.back Config.toml
   ```

3. **Model provider** (agent examples only) — fill in
   `[ballerina.ai.wso2ProviderConfig]` (serviceUrl + accessToken) in the
   package's `Config.toml`.

## ICP setup: users and roles for human tasks

Human tasks are completed through the Integration Control Plane (ICP) task
inbox. Reviews and tasks in these examples are gated by roles, so create the
following users/roles in your ICP instance before running:

| Role | Used by | Purpose |
| --- | --- | --- |
| `manager` | `expense-approval` | Decides the `approveExpense` human task (approve/reject a claim) |
| `support-lead` | `customer-support-agent` | Completes the `escalation` human task and approves gated `issueRefund` reviews |
| `manager` | `loan-approval` | Decides manual-retry reviews of the `transferFunds` activity (`retryPolicy = "manager"`) |

For a local trial, two users are enough — e.g. `alice` with role `manager` and
`bob` with role `support-lead`. Manual retry policies take the reviewer role(s) directly as the policy value
(`retryPolicy = "manager"` or `["finance", "manager"]`; an empty list allows
any role). Programmatic completion must pass matching
roles, e.g.:

```ballerina
check workflow:completeHumanTask(taskWorkflowId, decision, ["manager"], "alice");
```

## Running

Each package is self-contained: `bal run` inside the package directory. Start
with `loan-approval` — it needs no model credentials or human interaction and
completes end to end, so it verifies the module/Temporal setup.
