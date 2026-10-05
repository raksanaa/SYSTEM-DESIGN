# ADR-005 — Idempotency

## Status

Accepted

## Context

During a flash sale, customers may send the same request more than once because of:

* Network retries
* Browser refreshes
* Client-side retry logic
* API Gateway retries
* Payment-provider timeouts
* Users clicking the purchase button multiple times

Without idempotency, the same business operation could create:

* Multiple inventory reservations
* Multiple payment attempts or charges
* Duplicate order-processing requests

Therefore, reservation and payment commands must be safely repeatable.

## Decision

Require an idempotency key for:

* Inventory reservation requests
* Payment creation requests

The idempotency key is stored persistently and associated with the operation result.

For the same idempotency key and the same business operation:

> Return the previously stored result instead of executing the operation again.

If the same idempotency key is reused with different business data, reject the request.

## Idempotency Rules

### Rule 1 — Same key + same request

Return the existing result.

Example:

```text
Request 1:
Idempotency-Key: ABC123
Product: 1001
Quantity: 1

→ Reservation R100 created
```

If the client retries:

```text
Request 2:
Idempotency-Key: ABC123
Product: 1001
Quantity: 1

→ Return existing reservation R100
```

No second reservation is created.

### Rule 2 — Same key + different request

Reject the request.

Example:

```text
First request:
Idempotency-Key: ABC123
Product: 1001
Quantity: 1

Second request:
Idempotency-Key: ABC123
Product: 2001
Quantity: 1
```

The second request must not be executed because the same key represents a different business operation.

Return an appropriate client error such as:

```text
409 Conflict
```

### Rule 3 — Payment retry

If a payment request times out, the client may retry using the same idempotency key.

The Payment Service checks the stored idempotency record before creating another payment attempt.

This prevents accidental duplicate charges.

## Persistence

Idempotency records are stored in durable storage.

A record should contain information such as:

| Field            | Purpose                          |
| ---------------- | -------------------------------- |
| idempotency_key  | Unique client request identifier |
| operation_type   | Reservation or payment           |
| request_hash     | Detects conflicting reuse        |
| resource_id      | Reservation/payment created      |
| response_status  | Original response status         |
| response_payload | Original result                  |
| created_at       | Record creation time             |
| expires_at       | Retention/cleanup time           |

A unique constraint is placed on the idempotency key for the relevant operation.

## Processing Flow

```text
Client
   |
   | Request + Idempotency-Key
   v
API Gateway
   |
   v
Reservation / Payment Service
   |
   |-- Check idempotency record
   |
   |-- Existing + same request
   |       |
   |       └── Return stored result
   |
   |-- Existing + different request
   |       |
   |       └── Reject request
   |
   |-- No existing record
           |
           └── Execute operation
                   |
                   └── Store result
```

## Relationship with Inventory Concurrency

Idempotency and inventory concurrency solve different problems.

**Concurrency control** prevents multiple customers from consuming the same inventory.

**Idempotency** prevents the same customer request from being processed multiple times.

Both controls are required for the flash-sale purchase path.

## Relationship with Payment

Payment idempotency is especially important because a payment provider may successfully process a charge even when the response is lost because of a network timeout.

The system must reconcile the payment using the existing idempotency key or provider reference instead of blindly creating another charge.

## Cleanup and Retention

Idempotency records cannot be retained forever.

A cleanup/retention policy should remove records after the required retry and reconciliation window.

The retention period must be long enough to safely handle delayed retries and payment reconciliation.

## Consequences

### Advantages

* Prevents duplicate reservations.
* Prevents duplicate payment charges.
* Makes retries safe.
* Handles network failures more reliably.
* Supports at-least-once message/request delivery.
* Provides deterministic results for repeated requests.

### Disadvantages

* Requires persistent idempotency records.
* Adds storage and lookup overhead.
* Requires request hashing/comparison.
* Requires a cleanup and retention policy.
* Requires careful handling of concurrent requests using the same key.

## Decision Summary

SALESTORM uses persistent idempotency keys for reservation and payment commands.

```text
Same key + same operation
        ↓
Return existing result

Same key + different operation/data
        ↓
Reject request

New key
        ↓
Execute operation
        ↓
Store result
```

This prevents duplicate reservations and duplicate payment charges while allowing safe retries during the flash sale.
