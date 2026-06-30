# Human Task UI

A small Vite + React (TypeScript) single-page app for reviewers to act on the
human tasks and failed activities produced by the
[`../workflow`](../workflow) demo. It talks to the
`ballerina/workflow.management` API through a thin backend-for-frontend (BFF).

## Why a BFF?

The management API identifies the caller via `x-user-id` / `x-user-roles`
headers. A browser must never set those itself (any user could then claim any
role). So a small Express server (`server/index.mjs`) is the trust boundary:

```
browser ──login──▶ BFF ──(validates against users.txt)──▶ issues bearer token
browser ──/api/wf/* + Bearer──▶ BFF ──injects x-user-id/x-user-roles──▶ :8234/workflow/*
```

The BFF authenticates against a **plain-text user store** (`users.txt`, demo
only) and proxies `/api/wf/*` to the management API, injecting the logged-in
user's id and roles.

## User store

`users.txt`, one user per line — `username:password:comma,roles`:

```
alice:alice123:reviewer
bob:bob123:reviewer
carol:carol123:reviewer,admin
```

## Views

All lists are **paginated** (cursor-based, via the API's `pageToken` /
`nextPageToken`).

1. **Review Shipment Errors** — a list of `reviewErrorTaskProcess` instances
   showing status plus the count of **active human tasks** and **active failed
   activities**. Click a row to open the **workflow detail**, which shows the
   steps taken (from the activity tree), its human tasks, and its failed
   activities.
2. **Review Tasks** — human tasks for the logged-in reviewer, filterable by
   Pending / Completed / All. Open one to act on it. The detail is **tabbed**:
   - **Complete Task** — a form generated from the task schema + a primary
     *Complete Task* button.
   - **Task Actions** — *Fail task*, which opens a confirmation dialog with a
     reason (*Complete with Error*).
3. **Failed Activities** — manual-retry tasks, filterable by status. Open one to
   see the failure and either **Retry**, **Retry with new input**, or **Fail**
   it; once actioned the detail shows the outcome (who decided and when).

### Processing indicator

Workflow actions (completing a task, retrying an activity) advance the workflow
asynchronously, so after each action the UI shows a processing overlay, waits
briefly, and then refreshes so the updated status is visible.

## Dynamic rendering

- **Task input** is rendered from the task `payload` one level deep
  (`KeyValues`), so new payload fields appear automatically.
- **Completion form** is generated from the task's `formSchema` (a JSON schema
  the runtime derives from the task's result type). If a task has no schema, a
  per-task config or a raw-JSON editor is used.
- **Retry-with-input** form is generated from the failed activity's recorded
  `activityArgs`.

## Running

The UI needs the management API backed by a real server, so run the workflow app
in `LOCAL` mode against a Temporal dev server (see [../workflow](../workflow) and
the root README). Once `:8234` is up:

```bash
npm install
npm run dev      # starts the BFF (:3001) and Vite (:5173) together
```

Open http://localhost:5173 and sign in as `alice` / `alice123`.

### Configuration

| Env var      | Default                          | Purpose                         |
| ------------ | -------------------------------- | ------------------------------- |
| `PORT`       | `3001`                           | BFF port                        |
| `MGMT_URL`   | `http://localhost:8234/workflow` | Management API base URL         |
| `USERS_FILE` | `./users.txt`                    | Path to the plain-text store    |

## Layout

```
humantask_ui/
├── server/index.mjs     # BFF: login, sessions, header-injecting proxy
├── users.txt            # demo user store (plain text)
└── src/
    ├── api.ts           # typed calls to the BFF (incl. paginated list helpers)
    ├── auth.tsx         # auth context + token storage
    ├── dynamic.tsx      # dynamic value rendering + form generation
    ├── pagination.tsx   # usePagedList hook + Pager
    ├── processing.tsx   # processing overlay, modal, tabs
    ├── views/           # Login, Workflows(+Detail), Tasks(+Detail), FailedActivities(+Detail)
    └── styles.css       # white theme
```
