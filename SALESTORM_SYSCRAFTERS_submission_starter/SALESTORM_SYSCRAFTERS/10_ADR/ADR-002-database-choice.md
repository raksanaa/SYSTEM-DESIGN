# ADR-002 — Synchronous vs Asynchronous Workflow

## Status

Accepted

## Context

SALESTORM contains both operations that require an immediate response to the customer and operations that can safely happen asynchronously.

The flash-sale purchase flow must provide a clear and immediate result for inventory reservation. At the same time, downstream operations such as order creation, fulfilment and notifications can tolerate eventual consistency.

Using synchronous communication for every step would increase coupling and make downstream service failures directly affect the customer-facing purchase flow.

Using asynchronous communication for inventory reservation would make it difficult to provide an immediate reservation result and could complicate the inventory consistency boundary.

---

## Options

### Option A — Fully Synchronous Workflow

All operations are performed synchronously:

```text
Customer
   |
   v
Inventory
   |
   v
Payment
   |
   v
Order
   |
   v
Fulfilment
```

**Advantages:**

* Immediate response from each operation.
* Simple request flow.

**Disadvantages:**

* Creates strong coupling between services.
* A slow or unavailable downstream service can block the purchase request.
* Increases end-to-end latency.
* Makes failure recovery more difficult.

---

### Option B — Fully Asynchronous Workflow

All operations are submitted through asynchronous messaging.

**Advantages:**

* Loose coupling.
* Better burst handling.
* Services can recover independently.

**Disadvantages:**

* Inventory reservation cannot provide a simple immediate success/failure result.
* Customer experience becomes more complicated.
* Strong inventory consistency is harder to express in the immediate purchase path.

---

### Option C — Hybrid Synchronous + Asynchronous Workflow

Use synchronous communication where an immediate business result is required and asynchronous messaging for downstream operations.

```text
Customer
   |
   v
API Gateway
   |
   v
Inventory / Reservation
   |
   v
Immediate Result
   |
   +----------------------+
                          |
                          v
                    Message Broker
                          |
                 +--------+--------+
                 |                 |
                 v                 v
             Order Service   Notification /
                              Fulfilment
```

---

## Decision

Use a **hybrid synchronous and asynchronous workflow**.

### Synchronous

The following operations remain synchronous:

* Inventory reservation
* Immediate checkout validation
* Validation required to provide a clear customer-facing result

The customer should immediately know whether the reservation was successful or rejected.

### Asynchronous

The following operations use the message broker:

* Payment-success → Order creation
* Fulfilment processing
* Notifications
* Other downstream event-driven processing

---

## Reason

Inventory reservation requires a clear immediate result because inventory is the critical consistency boundary of the flash sale.

Downstream operations tolerate eventual consistency and benefit from:

* Durable messaging
* Retry
* Independent service recovery
* Loose coupling
* Failure isolation

---

## Failure Handling

If the Order Service is unavailable after a successful payment:

```text
Payment Succeeded
       |
       v
Message Broker
       |
       X
Order Service unavailable
       |
       v
Event retained / retried
       |
       v
Order Service recovers
       |
       v
Order created
```

The customer-facing inventory reservation does not depend on the Order Service being continuously available.

---

## Consequences

### Positive

* Immediate inventory result to the customer.
* Strong consistency is maintained where it matters most.
* Downstream services are loosely coupled.
* Payment-success events can survive temporary Order Service failures.
* Retry and recovery are easier for asynchronous operations.
* Fulfilment and notification processing can scale independently.

### Negative

* The system contains both synchronous and asynchronous communication paths.
* Downstream data may temporarily be eventually consistent.
* Event processing requires message retry and failure handling.
* Distributed tracing becomes important for following a purchase across services.

---

## Final Communication Model

```text
                 Customer
                    |
                    v
              API Gateway
                    |
                    v
          Inventory / Reservation
                    |
                    v
            Immediate Result
                    |
                    v
             Payment Processing
                    |
                    v
             Payment Succeeded
                    |
                    v
             Message Broker
                    |
             +------+------+
             |             |
             v             v
        Order Service   Fulfilment /
                         Notification
```

This hybrid model provides an immediate and strongly controlled inventory decision while allowing downstream operations to use durable asynchronous processing.
