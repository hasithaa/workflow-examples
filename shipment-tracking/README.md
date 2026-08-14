# Shipment tracking — durable workflow with data events

A plain durable workflow demonstrating **data events**: after booking the
courier, the workflow durably suspends on two `future` fields of its data-events
record — `pickedUp` and `delivered` — which the courier's callbacks deliver via
`workflow:sendData`, with a customer notification after each event.

The waits are crash-resumable: the workflow can sit between events for days,
survive worker restarts, and resume exactly where it left off.

## Run

```sh
temporal server start-dev   # in another terminal
bal run
```

Then drive it with the four `curl` commands the service prints: dispatch a
shipment, send the pickup and delivery confirmations, and read the result.

## Requirements

- `ballerina/workflow` **0.8.3**, resolved from Ballerina Central.
- Temporal dev server on `localhost:7233`.
