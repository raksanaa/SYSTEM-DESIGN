# SALESTORM – Security Design

## 1. Security Objectives

SALESTORM must protect:

* Customer accounts
* Cart and order information
* Payment information
* Inventory operations
* Administrative operations
* Internal service communication
* API endpoints

Security must not compromise the consistency requirements of the flash-sale workflow.

---

## 2. Transport Security

All external and internal network communication should use encrypted communication.

```text
Customer
   |
 HTTPS / TLS
   |
API Gateway
   |
 HTTPS / TLS
   |
Internal Services
```

TLS protects credentials, tokens and business data while in transit.

---

## 3. Authentication

SALESTORM APIs use authenticated requests.

The API Gateway validates the customer's bearer token/session before forwarding protected requests.

Example:

```text
Authorization: Bearer <token>
```

Unauthenticated requests are rejected before reaching protected business operations.

---

## 4. Authorization

Authentication confirms who the customer is.

Authorization determines what that customer is allowed to access.

For example:

```text
Customer A
    |
    +---- Own Cart       → ALLOWED
    |
    +---- Own Order      → ALLOWED
    |
    +---- Customer B Order → DENIED
```

Customers must not be able to access another customer's cart, reservation, payment or order information.

Administrative operations require appropriate administrative authorization.

---

## 5. API Gateway Protection

The API Gateway provides the first security boundary.

Responsibilities include:

* Authentication
* Authorization checks
* Rate limiting
* Request validation
* WAF integration
* Request size limits
* Basic abuse protection

---

## 6. Flash-Sale Rate Limiting

A flash sale can attract a large number of automated or abusive requests.

SALESTORM uses rate limiting and admission control to protect the purchase path.

```text
10,000 Requests
       |
       v
WAF / Rate Limiter
       |
       v
Sale Admission
       |
       v
Inventory Service
```

Rate limiting protects downstream services from uncontrolled request volume.

---

## 7. WAF and Abuse Protection

A Web Application Firewall can detect and block common malicious traffic patterns.

Examples include:

* SQL injection attempts
* Cross-site scripting attempts
* Malformed requests
* Excessive request rates
* Suspicious automated traffic

Bot and abuse protection is especially important during the flash-sale window.

---

## 8. Input Validation

All API inputs must be validated before processing.

Examples:

```text
productId → valid positive identifier
quantity  → positive value within allowed limit
amount    → valid monetary value
```

For the SALESTORM flash-sale scenario, the reservation API should enforce the maximum quantity allowed per request.

Invalid input must be rejected before reaching the inventory transaction.

---

## 9. Payment Data Protection

SALESTORM must not store raw card credentials.

Instead, the system should use payment-provider tokens or references.

```text
Customer
   |
   v
Payment Service
   |
   v
Payment Provider
   |
   v
Provider Token / Reference
```

The SALESTORM database stores only the required payment reference and transaction state.

---

## 10. Secrets Management

Sensitive configuration must not be committed to source control.

Examples:

* Database passwords
* JWT signing secrets
* Payment provider credentials
* API keys
* Encryption keys

These should be stored using a secrets manager or secure environment configuration.

Example:

```text
Application
     |
     v
Secrets Manager
     |
     +---- Database credentials
     +---- Payment credentials
     +---- Signing secrets
```

---

## 11. Audit Logging

Important business and administrative actions should be auditable.

Examples:

* Reservation created
* Reservation released
* Reservation expired
* Payment initiated
* Payment succeeded
* Payment failed
* Order created
* Order state changed
* Administrative inventory operation

Audit logs should contain enough information to investigate an incident without storing unnecessary sensitive data.

---

## 12. Customer Data Protection

Logs and monitoring systems must avoid exposing sensitive information.

Do not log:

* Passwords
* Raw card details
* Payment credentials
* Authentication tokens

Use non-sensitive identifiers such as:

```text
customer_id
reservation_id
order_id
trace_id
```

where appropriate.

---

## 13. Security Principles

SALESTORM follows these principles:

1. Encrypt network communication using TLS.
2. Authenticate protected API requests.
3. Authorize access to customer-owned resources.
4. Apply rate limiting during flash-sale traffic.
5. Use WAF and abuse protection.
6. Validate all incoming data.
7. Never store raw card credentials.
8. Keep secrets outside source control.
9. Maintain audit records for important business actions.
10. Avoid sensitive data in application logs.


# SALESTORM – Observability Design

## 1. Observability Objectives

SALESTORM requires observability to detect:

* Flash-sale traffic spikes
* Inventory reservation failures
* Payment failures and timeouts
* Duplicate requests
* Queue backlogs
* Database problems
* Service failures
* Delayed order creation
* Inventory inconsistencies

The three primary observability mechanisms are:

```text
Metrics
  +
Logs
  +
Distributed Tracing
```

---

# 2. Metrics

## Traffic Metrics

Monitor:

```text
requests_per_second
active_requests
HTTP_error_rate
p50_latency
p95_latency
p99_latency
```

These metrics help identify traffic spikes and degraded API performance.

---

## Inventory Metrics

Monitor:

```text
reservation_success_count
reservation_failure_count
out_of_stock_count
reservation_expiry_count
available_inventory
reserved_inventory
sold_inventory
```

These metrics help verify that inventory is behaving correctly during the flash sale.

---

## Payment Metrics

Monitor:

```text
payment_success_count
payment_failure_count
payment_timeout_count
payment_pending_count
payment_reconciliation_count
duplicate_payment_request_count
```

A sudden increase in payment timeouts can indicate a problem with the external payment provider.

---

## Messaging Metrics

Monitor:

```text
queue_depth
consumer_lag
message_retry_count
DLQ_message_count
event_processing_latency
```

These metrics help identify problems with asynchronous processing.

---

## Database Metrics

Monitor:

```text
DB_connection_utilization
query_latency
transaction_failure_count
lock_wait_time
connection_pool_usage
```

High database latency or lock contention can indicate a bottleneck in the inventory hot path.

---

# 3. Structured Logging

SALESTORM uses structured JSON logs rather than unstructured text.

Example:

```json
{
  "timestamp": "2026-10-05T10:30:15Z",
  "trace_id": "trace-123",
  "request_id": "req-456",
  "customer_id": "cust-1001",
  "product_id": "prod-101",
  "reservation_id": "res-789",
  "order_id": "ord-555",
  "event_type": "RESERVATION_CREATED",
  "status": "SUCCESS",
  "latency_ms": 42
}
```

Structured logs make searching, filtering and correlation easier.

---

# 4. Important Log Fields

Important fields include:

```text
timestamp
trace_id
request_id
customer_id
product_id
reservation_id
order_id
event_type
status
latency_ms
```

Sensitive credentials and payment information must not be logged.

---

# 5. Distributed Tracing

A trace should follow the complete purchase workflow.

```text
Customer
   |
   v
API Gateway
   |
   v
Checkout
   |
   v
Inventory
   |
   v
Payment
   |
   v
Message Broker
   |
   v
Order
   |
   v
Fulfilment
```

A common `trace_id` allows operators to follow a single transaction across services.

---

# 6. Example Trace

```text
trace_id = abc123

API Gateway
   |
   | 8 ms
   v
Checkout
   |
   | 15 ms
   v
Inventory
   |
   | 32 ms
   v
Payment
   |
   | 450 ms
   v
Message Broker
   |
   | 12 ms
   v
Order Service
```

This helps identify where latency is being introduced.

---

# 7. Alerts

SALESTORM should generate alerts for abnormal conditions.

### Inventory Alerts

* Inventory inconsistency detected
* Reservation failure spike
* Unexpected negative/invalid inventory state
* Out-of-stock rate suddenly increases

### Payment Alerts

* Payment failure spike
* Payment timeout spike
* Large number of pending payments
* Payment reconciliation backlog

### Messaging Alerts

* Queue backlog exceeds threshold
* Consumer lag exceeds threshold
* DLQ messages exceed threshold

### Database Alerts

* Database latency spike
* Database connection utilization too high
* Transaction failure spike
* Lock wait time exceeds threshold

### Order Alerts

* Order confirmation delay exceeds threshold
* Order Service unavailable
* Payment-success-to-order-created delay increases

---

# 8. Flash-Sale Dashboard

During the flash sale, operators should be able to monitor:

```text
+--------------------------------------+
|        SALESTORM DASHBOARD           |
+--------------------------------------+
| Requests/sec          | 10,000       |
| Active Requests       | ...          |
| p95 Latency           | ...          |
| Reservations Success  | ...          |
| Out of Stock           | ...          |
| Payment Failures      | ...          |
| Queue Depth            | ...          |
| Consumer Lag           | ...          |
| DLQ Messages          | ...          |
| DB Utilization        | ...          |
+--------------------------------------+
```

This provides a real-time view of the flash-sale health.

---

# 9. Reliability Correlation

Observability data should be correlated using identifiers.

```text
request_id
     |
     v
trace_id
     |
     +---- API logs
     |
     +---- Inventory logs
     |
     +---- Payment logs
     |
     +---- Broker events
     |
     +---- Order logs
```

This allows an individual purchase attempt to be investigated across the distributed system.

---

# 10. Key Observability Principles

1. Monitor traffic before the inventory hot path becomes overloaded.
2. Monitor inventory consistency continuously.
3. Track payment failures separately from payment timeouts.
4. Monitor message queue depth and consumer lag.
5. Track DLQ messages.
6. Use structured logs.
7. Propagate a common trace ID across services.
8. Avoid sensitive information in logs.
9. Alert on business-impacting failures, not only infrastructure failures.
10. Use dashboards during the flash-sale event for real-time visibility.
