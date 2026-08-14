# Customer support agent — single durable agentic workflow

A support triage agent declared as one module-level `workflow:DurableAgent`
object. Everything the agent can do is in the declaration:

- **Activities**: `lookupOrder`, and `issueRefund` gated with
  `requiresApproval: true` (a support lead approves each refund before it runs).
- **AI tool**: `policyLookup` for policy questions.
- **Human task**: `escalation` — the agent can hand hard cases to a person.
- **Conversation**: a `customerMessage` channel with `MULTI_EVENT` cardinality
  keeps the instance alive between turns; each turn is answered via its own
  correlation token.

The whole agent — reasoning steps, tool calls, approvals, turns — runs as a
durable workflow: crash the process and start it again, and open cases resume
exactly where they were.

## Run

```sh
temporal server start-dev   # in another terminal
# fill in [ballerina.ai.wso2ProviderConfig] in Config.toml first
bal run
```

Then drive a case with the three `curl` commands the service prints
(open case → follow-up turn → status). While a refund waits for approval,
`GET /support/cases/CS-1` reports `IN_PROGRESS`; approve the pending review to
let the run finish (pending reviews are visible via the workflow management
API / the BI inbox).

## Requirements

- `ballerina/workflow` **0.8.3**, resolved from Ballerina Central.
- Temporal dev server on `localhost:7233`.
- WSO2 model provider credentials in `Config.toml`.
