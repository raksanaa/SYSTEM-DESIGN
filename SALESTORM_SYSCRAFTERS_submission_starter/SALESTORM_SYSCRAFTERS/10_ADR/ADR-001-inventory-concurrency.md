# ADR-001 — Inventory Concurrency Control

## Status

Accepted

## Context

SALESTORM must support a flash-sale scenario where approximately **10,000 customers may attempt to purchase a product while only 100 units are available**.

The system must guarantee:

* Inventory never becomes negative.
* Inventory is never oversold.
* Concurrent reservation requests are handled safely.
* Duplicate reservation requests do not create additional reservations.
* The inventory database remains the final source of truth.

The flash-sale admission layer controls traffic reaching the inventory hot path, but correctness must still be guaranteed at the database boundary.

---

## Options

### Option A — Pessimistic Row Locking

Use:

```sql
SELECT ... FOR UPDATE
```

and then modify the inventory quantity inside the transaction.

**Pros:**

* Simple correctness model.
* Explicit row-level locking.
* Strong control over concurrent updates.

**Cons:**

* Lock contention can become severe for a hot SKU.
* Large numbers of concurrent requests can wait on the same inventory row.
* Longer transactions can reduce throughput.

---

### Option B — Optimistic Versioning

Read the inventory version and update only if the version has not changed.

Example:

```sql
UPDATE inventory
SET available_quantity = available_quantity - :qty,
    version = version + 1
WHERE product_id = :product_id
  AND version = :expected_version
  AND available_quantity >= :qty;
```

**Pros:**

* Avoids long-held application-side locks.
* Detects concurrent modifications.
* Version information can also support auditing.

**Cons:**

* Heavy contention on the same SKU can cause many conflicting retries.
* Retry storms can increase database load during a flash sale.

---

### Option C — Atomic Conditional SQL Update

Update inventory only when sufficient inventory is available.

Example:

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

```text
Affected rows = 1
        |
        v
Reservation successful

Affected rows = 0
        |
        v
Insufficient inventory / conflict
```

**Pros:**

* Correctness is enforced at the database boundary.
* Avoids application-side read-modify-write races.
* Compact transaction.
* Failed requests do not need to read inventory first and then attempt a separate update.
* Works well with the flash-sale inventory model.

**Cons:**

* The inventory row for a hot SKU can still become a write hotspot.
* The database remains a critical bottleneck for the inventory operation.

---

## Decision

Use **Option C — Atomic Conditional SQL Update** as the primary inventory reservation mechanism.

A **Sale Admission / Queue layer** is placed before the inventory service to control the rate at which requests reach the inventory hot path.

The reservation operation is executed within the database transaction boundary.

An **idempotency key** is stored with the reservation so that duplicate client requests can return the existing reservation result rather than creating another reservation.

The database remains the final authority for inventory availability.

---

## Concurrency Invariant

For every product:

```text
Reserved Quantity + Available Quantity
must never exceed the original sellable inventory
```

For the stated flash-sale scenario:

```text
Initial inventory = 100

Maximum successfully reserved quantity = 100
```

Therefore, even if thousands of customers request the product concurrently, the system cannot reserve more units than are actually available.

---

## Consequences

### Positive

* Prevents inventory overselling.
* Keeps inventory correctness inside the transactional database.
* Reduces application-side race conditions.
* Works with the admission-control layer to handle flash-sale bursts.
* Supports idempotent reservation requests.

### Negative

* The hot inventory row remains a deliberate write bottleneck.
* Database capacity and transaction performance must be monitored.
* Admission control is required to prevent uncontrolled pressure on the inventory database.

---

## Additional Decision

Redis may be used for caching or admission-related operations, but it **cannot independently declare inventory as sold**.

The SQL inventory transaction remains the final authority for reservation correctness.

```text
10,000 Requests
       |
       v
Sale Admission / Queue
       |
       v
Inventory Service
       |
       v
Atomic SQL Update
       |
       v
Database = Inventory Authority
```
