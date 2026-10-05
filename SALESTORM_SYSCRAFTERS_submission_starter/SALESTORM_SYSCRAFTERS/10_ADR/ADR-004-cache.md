# ADR-004 — Transactional Outbox

## Status

Accepted

## Problem

SALESTORM uses asynchronous events for communication between services.

A failure can occur if a service successfully updates its SQL database but crashes before publishing the corresponding event.

For example:

```text
SQL Transaction
      |
      v
Business state updated successfully
      |
      X
Service crashes
      |
      v
Event never reaches Message Broker
```

This can result in downstream services not receiving an important business event.

---

## Decision

Use the **Transactional Outbox Pattern**.

The business state change and the corresponding outbox event are written in the **same SQL transaction**.

```text
Database Transaction
        |
        +---- Update business state
        |
        +---- Insert Outbox Event
        |
        v
      COMMIT
```

After the transaction commits, a separate Outbox Publisher reads unpublished events and sends them to the message broker.

---

## Event Publishing Flow

```text
Service
   |
   v
SQL Transaction
   |
   +---- Business Table Update
   |
   +---- Outbox Event
   |
   v
Commit
   |
   v
Outbox Publisher
   |
   v
Message Broker
   |
   +------> Order Service
   |
   +------> Notification Service
   |
   +------> Fulfilment
```

---

## Outbox Event Information

An outbox record contains information such as:

```text
event_id
aggregate_id
event_type
payload
published
created_at
```

The `event_id` provides a unique identifier for the event.

---

## Failure Recovery

If the service crashes after the SQL transaction commits:

```text
Business state = COMMITTED
Outbox event = STORED
Event published = NO
```

The publisher can later find the unpublished event and retry publishing it.

```text
Outbox Table
     |
     | unpublished event
     v
Outbox Publisher
     |
     v
Message Broker
```

Therefore, the business event is not lost simply because the application crashed after committing the database transaction.

---

## Duplicate Event Handling

The publisher may successfully send an event to the broker but fail before marking the outbox record as published.

This can result in the same event being published again.

Therefore, downstream consumers should process events **idempotently**, using the event ID or another appropriate deduplication mechanism.

```text
Event ID = EVT-123

First delivery  → Process
Second delivery → Recognize duplicate → Do not repeat business operation
```

---

## Why Not Publish Directly After the Database Update?

Without an Outbox:

```text
UPDATE SQL
   |
   v
Publish Event
```

A crash between these operations can create a state where the database contains the business change but downstream services never receive the event.

With the Outbox:

```text
SQL Transaction
   |
   +---- Business Change
   |
   +---- Outbox Event
   |
   v
Commit
```

Both records are committed together.

---

## Trade-offs

### Advantages

* Prevents important events from being lost after a successful database transaction.
* Provides durable event storage.
* Supports retry after service failure.
* Works well with the asynchronous SALESTORM architecture.
* Creates a clear link between business state changes and published events.

### Disadvantages

* Adds an Outbox table.
* Requires an Outbox Publisher process.
* Requires monitoring of unpublished events.
* Consumers must handle possible duplicate event delivery.

---

## Decision Summary

SALESTORM will use the Transactional Outbox Pattern for important asynchronous business events.

```text
Business Change
      +
Outbox Event
      |
      v
Same SQL Transaction
      |
      v
Outbox Publisher
      |
      v
Message Broker
      |
      v
Downstream Services
```

This improves reliability while preserving the separation between synchronous business operations and asynchronous downstream processing.
