import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import * as api from "../api";
import { useAsync } from "../useAsync";
import { COMPLETION_FORMS, DynamicForm, fieldsFromJsonSchema, KeyValues } from "../dynamic";
import { Modal, ProcessingModal, Tabs, useProcessing } from "../processing";
import { isPending, shortTaskName } from "../types";
import { Empty, ErrorBanner, formatTime, Spinner, StatusBadge } from "../ui";

export default function TaskDetailView() {
  const { taskId = "" } = useParams();
  const task = useAsync(() => api.getHumanTask(taskId), [taskId]);
  const proc = useProcessing(() => task.reload());
  const [tab, setTab] = useState("complete");
  const [showFail, setShowFail] = useState(false);

  if (task.loading) return <Spinner />;
  if (task.error || !task.data) {
    return (
      <div>
        <Link className="back-link" to="/tasks">← Back to tasks</Link>
        <ErrorBanner error={task.error ?? "Task not found"} />
      </div>
    );
  }

  const t = task.data;
  const shortName = shortTaskName(t.taskName);
  const pending = isPending(t.status);
  // Prefer the server-provided JSON schema; fall back to a known form config.
  const formFields = fieldsFromJsonSchema(t.formSchema) ?? COMPLETION_FORMS[shortName];

  return (
    <div>
      <ProcessingModal open={proc.active} message={proc.message} />
      <Link className="back-link" to="/tasks">← Back to tasks</Link>

      <div className="card">
        <div className="card-head">
          <h3>{t.title || shortName}</h3>
          <StatusBadge status={t.status} />
        </div>
        <div className="card-body">
          {t.description && <p>{t.description}</p>}
          <Link className="muted small" to={`/workflows/${encodeURIComponent(t.parentWorkflowId)}`}>
            View workflow ↗
          </Link>
        </div>
      </div>

      <div className="card">
        <div className="card-head"><h3>Task input</h3></div>
        <div className="card-body">
          <KeyValues data={t.payload} />
        </div>
      </div>

      {proc.error && <div className="banner error">{proc.error}</div>}

      {pending ? (
        <div className="card">
          <div className="card-body">
            <Tabs
              active={tab}
              onChange={setTab}
              tabs={[
                { id: "complete", label: "Complete Task" },
                { id: "actions", label: "Task Actions" },
              ]}
            />

            {tab === "complete" &&
              (formFields ? (
                <DynamicForm
                  fields={formFields}
                  submitLabel="Complete Task"
                  busy={proc.active}
                  onSubmit={(result) =>
                    proc.run(() => api.completeHumanTask(t.taskId, result), {
                      pending: "Completing task…",
                    })
                  }
                />
              ) : (
                <RawResultForm
                  busy={proc.active}
                  onSubmit={(result) =>
                    proc.run(() => api.completeHumanTask(t.taskId, result), { pending: "Completing task…" })
                  }
                />
              ))}

            {tab === "actions" && (
              <div>
                <p className="muted">
                  Fail this task to finish it with an error instead of a normal result. This cannot be undone.
                </p>
                <button className="btn danger" onClick={() => setShowFail(true)}>
                  Fail task…
                </button>
              </div>
            )}
          </div>
        </div>
      ) : (
        <div className="card">
          <div className="card-head">
            <h3>Result</h3>
            <span className="muted small">
              {t.completedBy ? `by ${t.completedBy} · ` : ""}
              {formatTime(t.completedAt ?? t.closeTime)}
            </span>
          </div>
          <div className="card-body">
            {t.result ? <KeyValues data={t.result as Record<string, unknown>} /> : <Empty>No result recorded.</Empty>}
          </div>
        </div>
      )}

      {showFail && (
        <FailDialog
          busy={proc.active}
          onCancel={() => setShowFail(false)}
          onConfirm={(reason) => {
            setShowFail(false);
            proc.run(() => api.failHumanTask(t.taskId, reason), { pending: "Completing task with error…" });
          }}
        />
      )}
    </div>
  );
}

function FailDialog({
  busy,
  onConfirm,
  onCancel,
}: {
  busy: boolean;
  onConfirm: (reason: string) => void;
  onCancel: () => void;
}) {
  const [reason, setReason] = useState("");
  return (
    <Modal title="Complete with error?" onClose={onCancel}>
      <div className="form">
        <div className="field">
          <label>Reason *</label>
          <textarea
            rows={3}
            value={reason}
            autoFocus
            onChange={(e) => setReason(e.target.value)}
            placeholder="Why is this task being failed?"
          />
        </div>
        <div className="btn-row">
          <button className="btn danger" disabled={busy || !reason.trim()} onClick={() => onConfirm(reason.trim())}>
            Complete with Error
          </button>
        </div>
      </div>
    </Modal>
  );
}

function RawResultForm({ busy, onSubmit }: { busy: boolean; onSubmit: (result: unknown) => void }) {
  const [text, setText] = useState("{\n  \n}");
  const [error, setError] = useState<string | null>(null);
  return (
    <div className="form">
      <div className="field">
        <label>Result (JSON)</label>
        <textarea className="mono" rows={6} value={text} onChange={(e) => setText(e.target.value)} />
      </div>
      {error && <p className="error">{error}</p>}
      <button
        className="btn primary"
        disabled={busy}
        onClick={() => {
          try {
            onSubmit(JSON.parse(text));
            setError(null);
          } catch (e) {
            setError(`Invalid JSON: ${(e as Error).message}`);
          }
        }}
      >
        Complete Task
      </button>
    </div>
  );
}
