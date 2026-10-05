# Scalability & Reliability

## Traffic strategy
1. CDN/WAF handles public/cacheable traffic.
2. Load balancer distributes requests.
3. API Gateway applies authentication and rate limits.
4. Sale Admission controls the flash-sale hot path.
5. Queueing smooths bursts.
6. Stateless service replicas scale horizontally.
7. Product reads use Redis/cache.
8. Inventory writes remain strongly consistent in SQL.
9. Asynchronous order/notification/fulfilment work uses the broker.

## 10,000 -> 100 scenario
10,000 requests enter the admission layer.
Only admitted requests reach the inventory hot path at a controlled rate.
Each reservation attempts the atomic conditional update.
Exactly 100 successful one-unit reservations can occur.
Further attempts get OUT_OF_STOCK.

## 50x traffic
Do not simply create 50x database connections.
Increase edge capacity, service replicas, broker partitions and admission capacity while protecting the inventory write boundary.
The inventory row remains a controlled bottleneck by design.

## Failure handling
- Timeout: bounded retry with exponential backoff + jitter.
- Payment failure: release reservation.
- Payment timeout: reconcile using provider reference; do not blindly create another charge.
- Order Service down: durable PaymentSucceeded event remains queued and is retried.
- Consumer repeatedly fails: DLQ.
- Database failover: route to healthy primary/failover according to chosen SQL platform.
- Reservation expiry: scheduled worker scans indexed expiry/status and releases atomically.

## Bottleneck
The flash-sale inventory SKU is the deliberate consistency bottleneck.
The architecture controls access to it rather than allowing unbounded concurrent writes.
