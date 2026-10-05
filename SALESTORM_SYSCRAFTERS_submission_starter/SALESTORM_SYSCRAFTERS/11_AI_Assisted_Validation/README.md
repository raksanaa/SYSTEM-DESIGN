# Optional AI-Assisted Validation

## Demonstration

Run the simplified concurrency simulation:

```bash
python simulation.py
```

### Expected Invariants

The simulation should maintain the following invariants:

* Successful reservations <= 100
* Remaining stock >= 0
* Remaining stock + successful reservations = 100

These invariants represent the core requirement that the flash sale must never oversell the available inventory.

## What This Proves

The simulation validates the core concurrency invariant in a simplified environment.

It demonstrates that concurrent reservation attempts should not cause:

* Negative inventory.
* More than 100 successful reservations.
* Inconsistent remaining stock.

## What This Does NOT Prove

The simulation does not prove:

* Production throughput.
* Real network behaviour.
* Database latency under production load.
* Kafka/message-broker durability.
* Payment-provider behaviour.
* Cloud availability.
* Production infrastructure capacity.
* Real-world distributed failure behaviour.

The simulation is therefore considered a lightweight validation of the inventory-concurrency design, not a production benchmark.

## Recommended Second Demonstration

For a stronger validation, use a load-testing tool such as Postman, JMeter or Locust to simulate:

* 10,000 purchase requests.
* 100 available units.
* 2% duplicate requests.
* 95% simulated payment success.
* 30-second Order Service outage.

### Expected Result

The architecture should still produce:

```text
Successful reservations <= 100
Remaining inventory >= 0
```

No duplicate request should create an additional reservation when the same idempotency key is reused.

If the Order Service is unavailable, successful payment events should remain recoverable through the asynchronous messaging and retry mechanism.

## Validation Scope

The validation focuses primarily on:

1. Inventory concurrency.
2. Idempotency.
3. Reservation limits.
4. Payment failure/retry behaviour.
5. Order Service recovery.

The results should be documented along with the test conditions and observed output.
