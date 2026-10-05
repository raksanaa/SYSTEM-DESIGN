# SALESTORM — SysCrafters 2026

Design-first system design submission for a high-scale e-commerce flash sale.

## Core scenario
- 10,000 simultaneous purchase requests
- 100 available units
- No overselling
- Duplicate requests must be idempotent
- Reservations expire/release
- Payment must be safely retried
- Order workflow must recover from service failures
- Architecture should reason about normal ~10,000 req/s and flash-sale bursts up to ~500,000 req/s

## Recommended architecture
Users -> CDN/WAF -> Load Balancer -> API Gateway
-> Sale/Admission -> Product/Cart -> Inventory/Reservation
-> Checkout -> Payment -> Order -> Fulfilment/Shipment -> Notification

Supporting infrastructure:
- Redis: product cache, rate limiting, admission/short-lived state
- SQL database: authoritative inventory/order/payment state
- Kafka/RabbitMQ-style message broker: asynchronous events
- Outbox pattern: reliable event publication
- Monitoring/logging/tracing

## Critical inventory decision
The SQL inventory row is the source of truth. Reservation uses an atomic conditional update:

UPDATE inventory
SET available_quantity = available_quantity - :qty,
    reserved_quantity = reserved_quantity + :qty,
    updated_at = CURRENT_TIMESTAMP
WHERE product_id = :product_id
  AND available_quantity >= :qty;

If one row is updated, the reservation succeeds. If zero rows are updated, inventory is unavailable.

This is combined with a unique idempotency key so the same Buy request cannot create multiple reservations.

## Important rule
Design first. The prototype in `11_AI_Assisted_Validation/` is only evidence for the design; it is not the product implementation.
