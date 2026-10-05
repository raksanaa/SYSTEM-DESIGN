# ADR-003 — SQL as Inventory Source of Truth

## Status

Accepted

## Context

SALESTORM must maintain correct inventory during a flash sale where approximately **10,000 customers may attempt to purchase only 100 available units**.

The system requires:

* Transactions
* Primary and foreign keys
* Constraints
* Indexes
* Concurrency control
* Strong consistency for inventory reservation
* Reliable reservation, payment and order state

The inventory operation is therefore a critical consistency boundary.

---

## Options

### Option A — Relational SQL Database

Use a relational database for:

* Inventory
* Reservations
* Payments
* Orders

**Advantages:**

* Transaction support
* Constraints
* Foreign keys
* Indexes
* Atomic conditional updates
* Clear consistency boundary
* Structured relationships between business entities

**Trade-off:**

The hot inventory SKU can become a database write hotspot during a flash sale.

---

### Option B — NoSQL Database

Use a NoSQL database as the primary inventory store.

**Advantages:**

* Can provide high horizontal scalability depending on the selected technology.
* Flexible data models may be useful for some workloads.

**Trade-off:**

The required relational constraints and transaction model would need to be designed around the selected NoSQL technology.

---

### Option C — Redis as Inventory Authority

Use Redis as the final source of truth for inventory.

**Advantages:**

* Very low latency.
* High throughput.
* Useful for caching and admission-related workloads.

**Trade-off:**

Redis should not independently determine the authoritative business inventory state for SALESTORM because the challenge requires a clear transactional consistency boundary with persistent inventory, reservation and order state.

---

## Decision

Use a **relational SQL database as the authoritative source of truth** for:

* Inventory
* Reservations
* Payments
* Orders

The inventory reservation uses an atomic conditional SQL update:

```sql id="8s0rvh"
UPDATE inventory
SET available_quantity = available_quantity - :qty,
    reserved_quantity = reserved_quantity + :qty,
    version = version + 1,
    updated_at = CURRENT_TIMESTAMP
WHERE product_id = :product_id
  AND available_quantity >= :qty;
```

The database transaction determines whether the reservation succeeds.

---

## Role of Redis and Cache

Redis or another cache may be used for:

* Product reads
* Frequently accessed product information
* Admission-related acceleration
* Non-authoritative temporary data

However:

```text id="4q8m5x"
Redis / Cache
      |
      v
Performance optimization

SQL Database
      |
      v
Inventory correctness
```

The cache must not independently declare inventory as sold.

---

## Consistency Boundary

The SQL inventory record is the final authority.

```text id="aq2wcf"
Customer Request
       |
       v
Admission Layer
       |
       v
Inventory Service
       |
       v
SQL Transaction
       |
       +---- available_quantity >= qty
       |             |
       |             v
       |        Reservation succeeds
       |
       +---- insufficient quantity
                     |
                     v
              Reservation rejected
```

This ensures that concurrent requests cannot successfully reserve more inventory than is available.

---

## Consequences

### Positive

* Clear authoritative inventory state.
* Strong transactional boundary.
* Supports database constraints and relationships.
* Supports atomic inventory reservation.
* Reservation, payment and order state can be persisted reliably.
* Easier auditing and reconciliation.

### Negative

* The hot SKU remains a database write hotspot.
* Database performance must be monitored during the flash sale.
* The admission layer is required to protect the database from uncontrolled request bursts.
* Horizontal service scaling does not remove the inventory database bottleneck.

---

## Final Decision

SALESTORM uses:

```text id="v7f9k3"
Redis / Cache
      |
      | acceleration
      v
Application Services
      |
      v
SQL Database
      |
      +---- Inventory
      +---- Reservation
      +---- Payment
      +---- Order
```

**SQL is the final authority for inventory correctness; cache systems support performance but do not independently determine stock availability.**
