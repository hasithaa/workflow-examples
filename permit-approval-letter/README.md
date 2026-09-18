# Permit approval letter

A building permit application is assessed by one officer, the letter that decides
it is drafted by a durable agent, and a **second** officer signs it. The signature
on the issued letter is taken from the sign-off task's completion, so the letter
states who actually signed it rather than whatever its author typed.

This is the only example that pairs a **durable agent with a workflow**: the agent
writes the letter, the workflow owns the decision, the people and the delivery.

## What it demonstrates

| 0.10 feature | Where |
| --- | --- |
| `resultType` on an agent | `letterAgent` returns a `LetterDraft` record, so the workflow is not left parsing prose |
| `lastHumanTaskCompletion` | Reads who assessed the plans, and who signed the letter |
| `excludedUsers` | The assessing officer is excluded from the sign-off, so nobody signs their own assessment |
| `taskInputType` | The sign-off form shows the drafted letter as typed, read-only context |
| `RetryBeforeReview` | Posting is retried, and when the retries are spent an officer decides |
| `lastReviewDecision` | The outcome records whether a person had to intervene in the delivery |

## The flow

1. **Lodge** an application over HTTP. The workflow validates it.
2. **Assess** — a `permit-officer` checks the plans against the building code and
   records findings. An incomplete or non-compliant application ends here.
3. **Draft** — an activity drives `letterAgent`, which writes the letter around
   those findings and attaches the conditions published for the permit class.
4. **Sign** — a second `permit-officer` reads the draft, may replace its
   conditions, and signs or refuses. Whoever assessed the plans cannot sign: the
   workflow reads the assessment's completion and excludes that user, and the
   runtime enforces it.
5. **Issue and post** — the letter is registered and posted. The mock postal
   service is down for the first three attempts, so the retries are spent and a
   review is raised; an officer reruns the send and it succeeds.

## Roles

| Role | Purpose |
| --- | --- |
| `permit-officer` | Assesses the plans, signs the letter, and decides a failed delivery |
| `permit-admin` | Administrator on both tasks; may step in, and the letter then records that an administrator signed |

Two different users must hold `permit-officer`, otherwise the sign-off has nobody
to assign to once the assessor is excluded.

## Running

```sh
cp Config.toml.back Config.toml     # fill in the ICP secret and the model provider
bal run
```

```sh
curl -X POST localhost:9099/permits/applications \
  -H 'Content-Type: application/json' \
  -d '{"applicationId":"BP-1","applicant":"Rivera Builders","address":"14 Mill Lane",
       "permitClass":"residential-extension","description":"a single-storey rear extension"}'
```

Note the `workflowId` in the response. Decide the `assessPlans` task in the ICP
inbox, sign the `signPermitLetter` task **as a different user**, and decide the
delivery review when it appears. Then read the outcome:

```sh
curl localhost:9099/permits/applications/<workflowId>
```

```json
{
  "outcome": {
    "status": "GRANTED",
    "deliveryEscalated": true,
    "letter": {
      "reference": "PL-BP-1",
      "conditions": ["Works must start within 12 months of the date of this letter.", "..."],
      "signature": {"name": "officer-bob", "signedAt": "...", "asAdministrator": false}
    }
  }
}
```
