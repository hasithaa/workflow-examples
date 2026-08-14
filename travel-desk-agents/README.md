# Travel desk — multi-agent A2A delegation

Three durable agents cooperating agent-to-agent:

- **`flightAgent`** and **`hotelAgent`** — specialists, each with its own
  activities and instructions.
- **`travelDeskAgent`** — the coordinator. Its `peers` declaration advertises
  the specialists to its model as delegable tools:
  - `askFlightDesk` — **synchronous** delegation (`'wait: true`, the default):
    the coordinator's tool call durably suspends until the peer agent finishes.
  - `askHotelDesk` — **asynchronous** delegation (`'wait: false`): the tool call
    returns immediately and the peer's final answer is delivered later as an
    event on the declared `hotelResults` callback channel.

Each delegation runs the peer agent as a true Temporal **child workflow** of the
coordinator, so the whole multi-agent conversation is durable and
crash-resumable.

## Run

```sh
temporal server start-dev   # in another terminal
# fill in [ballerina.ai.wso2ProviderConfig] in Config.toml first
bal run
```

The run prints the coordinator's combined itinerary once both specialists have
answered.

## Requirements

- `ballerina/workflow` **0.8.3**, resolved from Ballerina Central.
- Temporal dev server on `localhost:7233`.
- WSO2 model provider credentials in `Config.toml`.

> Note: asynchronous peer delegation is the least-exercised path in the module
> test suite so far — if the coordinator stalls waiting on `hotelResults`,
> capture the worker log; that is exactly the kind of finding these examples
> are for.
