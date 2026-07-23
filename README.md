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
| [`expense-approval`](expense-approval/) | Expense reimbursement | **Human task**: `ctx->awaitHumanTask` with typed decision, payload, roles and timeout; completed via `workflow:completeHumanTask` |
| [`shipment-tracking`](shipment-tracking/) | Courier tracking | **Data events**: two `future` data events (`pickedUp`, `delivered`) driven by `workflow:sendData` callbacks |
| [`customer-support-agent`](customer-support-agent/) | Support triage | **Single durable agent**: activities, approval-gated refunds, AI tool, human-task escalation, multi-turn conversation channel |
| [`travel-desk-agents`](travel-desk-agents/) | Trip planning | **Multi-agent / A2A**: coordinator + two specialist peer agents, synchronous and asynchronous (callback channel) delegation |

## Prerequisite: the unreleased `workflow` 0.8.0 module

These examples rely on an **unreleased 0.8.0 build** of `ballerina/workflow` —
the object-model durable agent and child-workflow APIs from the in-review PRs
([#69](https://github.com/ballerina-platform/module-ballerina-workflow/pull/69),
[#70](https://github.com/ballerina-platform/module-ballerina-workflow/pull/70)).
It is **not on Ballerina Central**: build it yourself and publish it to the
**local repository**.

```sh
git clone https://github.com/ballerina-platform/module-ballerina-workflow
cd module-ballerina-workflow
git fetch origin pull/70/head:durable-agent-object-model
git checkout durable-agent-object-model
./gradlew :workflow-ballerina:build -x test

# publish the built bala to the local repository
mkdir -p ~/.ballerina/repositories/local/bala/ballerina/workflow
cp -R target/ballerina-runtime/repo/bala/ballerina/workflow/0.8.0 \
      ~/.ballerina/repositories/local/bala/ballerina/workflow/0.8.0
```

Every example's `Ballerina.toml` pins `ballerina/workflow` 0.8.0 with
`repository = "local"`. If you rebuild the module, also purge the extracted
cache (`~/.ballerina/repositories/local/cache-*/ballerina/workflow`) so the old
build does not shadow the new one. `ballerina/ai` is pinned to 1.11.2 (the
1.12.0 BIR is incompatible with this distribution).

## Runtime setup

1. **Temporal** — all examples expect a dev server on `localhost:7233`:

   ```sh
   temporal server start-dev
   ```

2. **Model provider** (agent examples only) — fill in
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
