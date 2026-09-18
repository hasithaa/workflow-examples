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
| [`permit-approval-letter`](permit-approval-letter/) | Building permits | **Agent inside a workflow**: an agent drafts the decision letter, one officer assesses and a second signs (`excludedUsers`), and the signature comes from the task's own completion (`lastHumanTaskCompletion`) |
| [`shipment-tracking`](shipment-tracking/) | Courier tracking | **Data events**: two `future` data events (`pickedUp`, `delivered`) driven by `workflow:sendData` callbacks |
| [`customer-support-agent`](customer-support-agent/) | Support triage | **Single durable agent**: activities, approval-gated refunds, AI tool, human-task escalation, multi-turn conversation channel |
| [`travel-desk-agents`](travel-desk-agents/) | Trip planning | **Multi-agent / A2A**: coordinator + two specialist peer agents, synchronous and asynchronous (callback channel) delegation |

## Prerequisite: the `workflow` module

These examples use the **0.10 task model** of `ballerina/workflow` — approval
policies, review definitions with a named audience, and task administrators —
released as [0.10.0 on Central](https://central.ballerina.io/ballerina/workflow/0.10.0).
`bal build` resolves it; no local repository step is needed.

The expense examples also pull the released `wso2/icp.runtime.bridge` 1.0.0
from Central. The examples target distribution **2201.13.4** (Swan Lake Update 13).

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
| `permit-officer` | `permit-approval-letter` | Assesses the plans, signs the letter, and decides a failed delivery. **Two users must hold it**: the assessor is excluded from the sign-off |
| `permit-admin` | `permit-approval-letter` | Administrator on both permit tasks; a letter signed by an administrator records that |
| `manager` | `loan-approval` | Decides manual-retry reviews of the `transferFunds` activity (`retryPolicy = {userRoles: "manager"}`) |
| `expense-admin` | `expense-approval`, `expense-approval-agent` | Administers every expense task: sees it beside the managers, may reassign it, move its deadline, or decide it (recorded as an administrator's decision) |

For a local trial, three users are enough — e.g. `alice` with role `manager`,
`bob` with role `support-lead` and `sam` with role `expense-admin`. A review is
declared as a `ReviewTaskDefinition` — `{userRoles: "manager"}`, optionally with
`users`, `excludedUsers`, `excludedRoles` and `administratorRoles` — wherever a
policy is expected (`retryPolicy`, `approvalPolicy`). Programmatic completion
must pass matching roles, e.g.:

```ballerina
check workflow:completeHumanTask(taskWorkflowId, decision, ["manager"], "alice");
```

## Running

Each package is self-contained: `bal run` inside the package directory. Start
with `loan-approval` — it needs no model credentials or human interaction and
completes end to end, so it verifies the module/Temporal setup.
