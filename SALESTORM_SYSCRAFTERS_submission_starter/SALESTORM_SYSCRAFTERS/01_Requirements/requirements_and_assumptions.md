# 01 — Requirements & Assumptions

## Problem

SALESTORM is a flash-sale e-commerce platform where thousands of customers may purchase a limited-stock product simultaneously.

The critical scenario is:

> 10,000 customers attempt to purchase a product while only 100 units are available.

The system must handle the burst while guaranteeing that inventory is never oversold.

## Functional Requirements

1. Customer can discover products and sale information.
2. Customer can add products to a cart.
3. Customer can submit a Buy/Checkout request.
4. System can reserve available inventory temporarily.
5. Reservation has an expiry time.
6. Payment can succeed, fail or time out.
7. Duplicate payment requests must not create duplicate transactions.
8. Successful payment must eventually produce a valid order.
9. Failed/expired reservations must be released.
10. Order progresses through fulfilment and delivery states.
11. Customer receives notification events.
12. Critical business actions are auditable.

## Non-Functional Requirements

| Requirement                  | Target / Guarantee                               |
| ---------------------------- | ------------------------------------------------ |
| Concurrent purchase attempts | 10,000                                           |
| Flash-sale inventory         | 100 units                                        |
| Inventory correctness        | Never sell more than 100 units                   |
| Normal traffic               | ~10,000 req/s                                    |
| Flash-sale reasoning target  | Up to 500,000 req/s                              |
| Availability                 | Horizontally scalable; exact SLA to be finalized |
| Reservation                  | Temporary + expiring                             |
| Payment                      | Idempotent                                       |
| Recovery                     | Retry/reconciliation defined                     |
| Security                     | HTTPS, authentication, authorization, validation |
| Observability                | Metrics, logs, traces, alerts                    |

## Strict Guarantees

The following are correctness guarantees of the architecture:

* Inventory cannot become negative.
* Successful reservations cannot exceed available inventory.
* A single idempotency key maps to one business result.
* Duplicate payment requests cannot create duplicate payment transactions.
* Expired reservations are eventually released.
* Payment/order events are not silently lost.

### Core Flash-Sale Invariant

For the 100-unit flash-sale scenario:

```text
Successful Reservations <= 100
Remaining Inventory >= 0

Successful Reservations + Remaining Inventory = 100
```

The inventory source of truth must enforce this invariant at the concurrency boundary.

## Performance and Availability Targets

* Low latency for product browsing and admission.
* High availability for stateless APIs.
* Horizontal scaling during flash-sale bursts.
* The inventory hot SKU remains a controlled consistency bottleneck rather than allowing unlimited concurrent writes.

## Assumptions

* One sale SKU is the critical hot item.
* Inventory is authoritative in SQL.
* Redis is not treated as the final inventory source of truth.
* A message broker provides durable asynchronous delivery.
* Payment provider supports an idempotency/reference key.
* Reservation TTL is configurable; example: 10 minutes.
* At-least-once event delivery is assumed, so consumers must be idempotent.

## Constraints

* Design quality is more important than production code.
* Every team member must understand the complete architecture.
* AI may accelerate prototype/tests/docs but cannot replace architecture reasoning.
* The architecture must prioritize inventory correctness during flash-sale concurrency.
* The final design should clearly explain trade-offs rather than assuming that one technology solves every scalability or reliability problem.

## Requirement-to-Design Traceability

| Requirement                         | Main Design Response                                |
| ----------------------------------- | --------------------------------------------------- |
| 10,000 concurrent purchase attempts | Admission/queue layer                               |
| Only 100 units available            | Atomic conditional inventory update                 |
| No overselling                      | SQL inventory source of truth + concurrency control |
| Duplicate requests                  | Idempotency keys                                    |
| Temporary reservation               | Reservation status + expiry time                    |
| Payment timeout                     | Retry/reconciliation                                |
| Payment failure                     | Reservation release/compensation                    |
| Order Service failure               | Durable events + retry/DLQ                          |
| Event loss prevention               | Transactional outbox                                |
| High read traffic                   | Cache/Redis                                         |
| Horizontal scaling                  | Stateless service replicas                          |
| Security                            | TLS, authentication, authorization, validation      |
| Operational visibility              | Metrics, logs, traces and alerts                    |
