# SALESTORM – Scalability and Reliability

## 1. Objective

SALESTORM must support a flash-sale scenario where approximately **10,000 customers may attempt to purchase a product at the same time while only 100 units are available**.

The system must:

* Prevent inventory overselling
* Handle duplicate requests safely
* Handle payment failures and timeouts
* Handle reservation expiry
* Recover from Order Service failures
* Prevent cascading failures
* Support retries without creating duplicate transactions
* Preserve important events during service failures
* Provide monitoring and operational visibility

---

# 2. Scalability Strategy

## 2.1 Request Flow

```text
10,000 Customers
        |
        v
Load Balancer
        |
        v
API Gateway
        |
        v
Admission Control / Queue
        |
        +--------------------+
        |                    |
        v                    v
Inventory Service       Other Services
        |
        v
Inventory Database
```

The API Gateway and admission-control mechanism prevent all incoming requests from directly overwhelming the Inventory Service and database.

---

## 2.2 Horizontal Scaling

Stateless services can be horizontally scaled.

```text
                    Load Balancer
                         |
             +-----------+-----------+
             |           |           |
             v           v           v
        API Instance  API Instance  API Instance
             |           |           |
             +-----------+-----------+
                         |
                    Shared Services
```

The following services can have multiple instances:

* API Gateway
* Inventory Service
* Payment Service
* Order Service

State that must be shared between instances is stored in persistent databases, Redis where appropriate, or the message broker.

---

# 3. Inventory Scalability and No Overselling

Inventory is the most critical consistency requirement.

For 100 available units, the system must never allow the committed quantity to become greater than 100.

The reservation operation uses an atomic database update:

```sql
UPDATE inventory
SET available_quantity = available_quantity - :qty,
    reserved_quantity = reserved_quantity + :qty,
    version = version + 1,
    updated_at = CURRENT_TIMESTAMP
WHERE product_id = :product_id
  AND available_quantity >= :qty;
```

The application checks the number of affected rows.

### Successful update

```text
Affected rows = 1
        |
        v
Reservation successful
```

### Failed update

```text
Affected rows = 0
        |
        v
Insufficient inventory
        |
        v
Return conflict / sold out
```

This prevents two concurrent transactions from both successfully reserving the same final unit.

---

# 4. Concurrency Control

SALESTORM compares multiple approaches.

| Approach                  | Advantage                                  | Limitation                                 | SALESTORM Decision                          |
| ------------------------- | ------------------------------------------ | ------------------------------------------ | ------------------------------------------- |
| Pessimistic row locking   | Strong control over concurrent updates     | Can increase lock contention               | Not primary approach                        |
| Optimistic locking        | Detects conflicting updates using version  | Requires retry/conflict handling           | Useful for selected updates                 |
| Atomic conditional update | Simple and efficient inventory reservation | Requires careful transaction design        | **Primary strategy**                        |
| Distributed lock          | Can coordinate distributed workers         | Adds infrastructure and failure complexity | Not required for core inventory reservation |

### Selected Approach

SALESTORM uses an **atomic conditional database update** as the primary inventory reservation mechanism.

A version column is also maintained for concurrency detection and auditing.

---

# 5. Idempotency

Idempotency prevents duplicate operations when clients retry requests.

Important operations use an idempotency key.

Examples:

```text
POST /reservations
Idempotency-Key: RES-12345
```

```text
POST /payments
Idempotency-Key: PAY-12345
```

The service first checks whether the key already exists.

```text
Request
   |
   v
Idempotency lookup
   |
   +---- Existing result ---> Return existing result
   |
   +---- New request -------> Process operation
```

### Business Result

A repeated request must not:

* Create another reservation
* Charge the customer twice
* Create duplicate orders

---

# 6. Retry Strategy

Retries are only performed for operations that are safe to retry.

### Retryable conditions

Examples:

* Temporary network failure
* HTTP 502/503/504
* Temporary database connectivity failure
* Temporary message broker failure

### Non-retryable conditions

Examples:

* Invalid request
* Authentication failure
* Insufficient inventory
* Invalid payment details
* Expired reservation

---

## 6.1 Exponential Backoff

Retries use bounded exponential backoff.

Example:

```text
Attempt 1 → immediate
Attempt 2 → short delay
Attempt 3 → longer delay
Attempt 4 → maximum configured delay
```

A maximum retry count prevents an endless retry loop.

---

# 7. Timeout Handling

Every remote call must have a timeout.

Example:

```text
SALESTORM Service
       |
       | timeout configured
       v
External Payment Gateway
```

If the payment provider does not respond within the configured timeout, SALESTORM must **not assume that the payment failed**.

Instead:

```text
Payment Timeout
      |
      v
Payment = PENDING / UNKNOWN
      |
      v
Reconciliation
      |
      v
Query payment provider
      |
      v
Final payment state
```

This prevents an actual successful payment from being incorrectly treated as a failed payment.

---

# 8. Circuit Breaker

The Payment Service uses a circuit breaker when communicating with an external payment provider.

```text
             CLOSED
                |
         repeated failures
                |
                v
              OPEN
                |
          recovery delay
                |
                v
           HALF-OPEN
             /     \
       success     failure
          |           |
          v           v
       CLOSED       OPEN
```

### CLOSED

Requests are allowed normally.

### OPEN

Requests are blocked temporarily because the dependency is unhealthy.

### HALF-OPEN

A limited request is allowed to test whether the dependency has recovered.

### Business Benefit

The circuit breaker prevents a failing payment provider from causing cascading failures throughout SALESTORM.

---

# 9. Reservation Expiry

Reservations are temporary.

Each reservation contains:

```text
reservation_id
status
expires_at
```

An expiry worker periodically checks expired reservations.

```text
Reserved
   |
   | expires_at reached
   v
Expired
   |
   v
Atomic inventory release
   |
   v
Available quantity restored
```

The release operation must be atomic and must only release an appropriate reservation state.

This prevents expired reservations from permanently blocking inventory.

---

# 10. Payment Failure Handling

If payment fails:

```text
Payment Service
      |
      v
Payment Failed
      |
      v
Release Reservation
      |
      v
Inventory Available Again
```

Business result:

```text
Payment Failed
     ↓
No completed sale
     ↓
Inventory returned
```

The release operation should be idempotent so that repeated failure events do not release the same inventory multiple times.

---

# 11. Payment Timeout and Reconciliation

Payment timeout is different from payment failure.

```text
Payment Request
      |
      v
External Gateway
      |
      X
No response
      |
      v
PAYMENT_PENDING
      |
      v
Reconciliation Worker
      |
      v
Query Provider Using Reference
      |
      +----------+----------+
      |                     |
      v                     v
Successful              Failed
      |                     |
      v                     v
Confirm Payment        Release Reservation
```

This ensures that SALESTORM does not accidentally charge or refund incorrectly because of an ambiguous network timeout.

---

# 12. Transactional Outbox

SALESTORM uses the Outbox pattern for reliable event publishing.

Instead of:

```text
Update Database
       |
       v
Publish Event
```

the service performs:

```text
Database Transaction
       |
       +---- Update business data
       |
       +---- Insert event into Outbox
       |
       v
Commit
```

A separate publisher then sends the event:

```text
Outbox Table
     |
     v
Outbox Publisher
     |
     v
Message Broker
     |
     +------> Order Service
     |
     +------> Inventory Service
     |
     +------> Notification Service
```

### Benefit

If the service crashes immediately after the database transaction commits, the event remains in the Outbox and can still be published later.

---

# 13. Message Retry and Dead Letter Queue

Messages that temporarily fail are retried.

```text
Message Broker
      |
      v
Consumer
      |
      +---- Success ---> Processed
      |
      +---- Temporary Failure
                  |
                  v
                Retry
                  |
                  v
              Consumer
```

If a message repeatedly fails:

```text
Repeated Failure
       |
       v
Dead Letter Queue
       |
       v
Manual / Automated Investigation
```

The DLQ prevents a poison message from continuously blocking normal event processing.

---

# 14. Order Service Failure

The Order Service may temporarily become unavailable after payment succeeds.

SALESTORM does not lose the payment event.

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
Message retained / retry
       |
       v
Order Service recovers
       |
       v
Order Created
```

This provides eventual order creation without requiring the Payment Service to remain synchronously dependent on the Order Service.

---

# 15. Compensation and Reconciliation

Distributed operations can reach intermediate states.

Example:

```text
Reservation = CONFIRMED
Payment = UNKNOWN
Order = NOT_CREATED
```

A reconciliation process checks these inconsistent or incomplete states.

Possible actions include:

* Query payment provider
* Retry event publication
* Create missing order
* Release expired reservation
* Trigger refund/compensation where required
* Record reconciliation result

The objective is to converge the system toward a consistent business state.

---

# 16. Redis Failure

Redis may be used for caching or non-critical acceleration.

If Redis becomes unavailable:

```text
Application
     |
     X
Redis unavailable
     |
     v
Fallback to SQL / primary data source
```

Redis must not be the sole source of truth for inventory correctness.

Inventory correctness remains in the transactional database.

Therefore:

```text
Redis failure
      ↓
Performance degradation
      ↓
NOT inventory corruption
```

---

# 17. Failure Matrix

| Failure                      | Detection                    | Response                                 | Business Result            |
| ---------------------------- | ---------------------------- | ---------------------------------------- | -------------------------- |
| API timeout                  | Latency metric / timeout     | Retry only safe or idempotent requests   | No duplicate transaction   |
| Inventory DB timeout         | DB metrics / timeout         | Bounded retry and fail closed            | No unsafe reservation      |
| Payment failure              | Provider response            | Mark failed and release reservation      | No completed sale          |
| Payment timeout              | Timeout + reconciliation     | Query provider using same reference      | One final payment state    |
| Duplicate payment            | Idempotency lookup           | Return existing result                   | One charge                 |
| Order Service down           | Broker lag / consumer health | Retain and retry event                   | Eventual order creation    |
| Consumer poison message      | Repeated consumer failures   | Move to DLQ                              | Failure isolated           |
| Reservation expiry           | Expiry worker                | Atomic inventory release                 | Stock returned             |
| Redis unavailable            | Cache error                  | Bypass cache where safe                  | Correctness remains in SQL |
| Message broker unavailable   | Broker health metrics        | Retry event publishing through Outbox    | Event not lost             |
| Payment provider unavailable | Circuit breaker metrics      | Open circuit and fail/reconcile safely   | Prevent cascading failure  |
| Service instance failure     | Health checks                | Load balancer routes to healthy instance | Service remains available  |

---

# 18. Observability for Reliability

SALESTORM should monitor:

### Traffic

* Requests per second
* Active users
* Admission queue size
* HTTP error rate

### Inventory

* Available quantity
* Reserved quantity
* Sold quantity
* Reservation failures
* Reservation expiry count

### Payment

* Payment success rate
* Payment failure rate
* Payment timeout count
* Pending payments
* Reconciliation count

### Messaging

* Queue depth
* Consumer lag
* Retry count
* DLQ message count

### Database

* Query latency
* Connection pool usage
* Lock wait time
* Transaction failures

### Reliability

* Service availability
* Circuit breaker state
* Retry rate
* Error rate
* Recovery time

---

# 19. Reliability Principles

SALESTORM follows these principles:

1. **Inventory database is the source of truth for stock.**
2. **Never reserve inventory without an atomic consistency check.**
3. **Never blindly retry non-idempotent operations.**
4. **Payment timeout does not automatically mean payment failure.**
5. **Use idempotency keys for duplicate-sensitive operations.**
6. **Use bounded retries with exponential backoff.**
7. **Use circuit breakers for unstable external dependencies.**
8. **Use the Outbox pattern so important events are not lost.**
9. **Use a DLQ for repeatedly failing messages.**
10. **Use reconciliation to recover from ambiguous distributed states.**
11. **Redis improves performance but is not the source of inventory truth.**
12. **Prefer eventual consistency between independent services while maintaining strong consistency for inventory reservation.**

---

# 20. Expected Flash-Sale Result

For the target scenario:

```text
10,000 customers
       |
       v
Admission Control
       |
       v
Inventory Reservation
       |
       v
Only 100 successful reservations
       |
       +---- Remaining requests
                    |
                    v
              SOLD OUT / CONFLICT
```

The architecture must guarantee:

```text
Successful reservations <= Available inventory
```

Therefore:

```text
10,000 concurrent attempts
            +
100 available units
            ↓
No overselling
            ↓
At most 100 units reserved
```

This is the primary reliability and concurrency objective of SALESTORM.
