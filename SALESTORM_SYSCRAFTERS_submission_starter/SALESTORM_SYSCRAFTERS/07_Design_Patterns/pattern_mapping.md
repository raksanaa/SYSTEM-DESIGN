# SALESTORM – Design Pattern Mapping

## 1. Purpose

This document maps the selected software design patterns to the SALESTORM flash-sale system.

The patterns are chosen to support:

* High-concurrency flash-sale processing
* Inventory reservation and consistency
* Payment provider integration
* Order and reservation lifecycle management
* Failure handling and recovery
* Separation of responsibilities between services

---

## 2. Design Pattern Mapping

| Pattern             | Where Used in SALESTORM                               | Problem Solved                                                                                          | Trade-off                                                           |
| ------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| **Strategy**        | Payment provider selection and payment retry strategy | Allows different payment providers or payment strategies to be selected without changing checkout logic | Adds abstraction and multiple strategy implementations              |
| **Factory**         | Payment provider creation                             | Centralizes creation of payment provider implementations                                                | Adds an additional layer of indirection                             |
| **State**           | Order and reservation lifecycle                       | Prevents invalid lifecycle transitions such as paying for an expired reservation                        | Requires additional state logic/classes                             |
| **Observer**        | Domain events and asynchronous notifications          | Decouples Order, Payment, Inventory and Notification consumers                                          | Introduces eventual consistency                                     |
| **Adapter**         | External payment gateway integration                  | Converts provider-specific APIs into SALESTORM's common payment interface                               | Requires mapping and conversion code                                |
| **Repository**      | Inventory, Reservation, Order and Payment persistence | Separates business logic from database-specific operations                                              | Adds repository interfaces and implementation layers                |
| **Facade**          | Checkout/purchase orchestration                       | Provides a simple entry point for coordinating reservation, payment and order operations                | Can become too large if too much business logic is placed inside it |
| **Circuit Breaker** | Payment gateway and other external service calls      | Prevents repeated calls to an unavailable dependency and allows the system to fail fast                 | Requires threshold, timeout and recovery configuration              |

---

## 3. Strategy Pattern

### Location

**Payment Service**

### Example

SALESTORM can support multiple payment providers:

```text
PaymentService
      |
      +---- PaymentStrategy
                |
                +---- ProviderA
                |
                +---- ProviderB
                |
                +---- ProviderC
```

The Payment Service does not need to contain provider-specific payment logic.

It selects the appropriate strategy:

```text
PaymentService
      |
      v
PaymentStrategy
      |
      +--> PaymentProviderA
      |
      +--> PaymentProviderB
```

### Problem Solved

Different payment providers can have different APIs and processing behaviour.

The Strategy pattern allows the payment algorithm/provider to be changed without modifying the main payment workflow.

### Benefit

The system follows the **Open/Closed Principle** because new payment strategies can be added without rewriting the existing payment service.

### Trade-off

Additional interfaces and strategy implementations increase the number of classes.

---

## 4. Factory Pattern

### Location

**Payment Service**

### Purpose

The Factory creates the appropriate payment provider implementation.

Example:

```text
PaymentProviderFactory
        |
        +--> ProviderA
        |
        +--> ProviderB
```

The Payment Service requests a provider from the factory instead of directly creating provider objects.

### Problem Solved

Centralizes provider creation and prevents provider-construction logic from being scattered throughout the application.

### Trade-off

Introduces another abstraction layer.

---

## 5. State Pattern

### Location

**Reservation and Order Services**

SALESTORM contains important lifecycle states.

### Reservation lifecycle

```text
AVAILABLE
    |
    v
RESERVED
    |
    +------> EXPIRED
    |
    +------> RELEASED
    |
    +------> CONFIRMED
```

### Order lifecycle

```text
CREATED
   |
   v
PAYMENT_PENDING
   |
   +------> PAYMENT_FAILED
   |
   +------> CONFIRMED
              |
              v
           COMPLETED
```

The State pattern helps ensure that only valid state transitions are allowed.

### Example

An expired reservation should not be allowed to move directly to a confirmed order.

### Problem Solved

Prevents invalid transitions in reservation and order lifecycles.

### Trade-off

State handling introduces additional logic and potentially additional state classes.

---

## 6. Observer Pattern

### Location

**Event-driven communication**

SALESTORM uses asynchronous events between services.

Example:

```text
Payment Service
      |
      | PaymentSucceeded
      v
 Message Broker
      |
      +--------> Order Service
      |
      +--------> Inventory Service
      |
      +--------> Notification Service
```

A service publishes an event without directly calling every consumer.

### Example Events

```text
ReservationCreated
ReservationExpired
PaymentSucceeded
PaymentFailed
OrderCreated
OrderConfirmed
```

### Problem Solved

Prevents tight coupling between services.

For example, the Payment Service does not need to know all the consumers of `PaymentSucceeded`.

### Trade-off

Consumers may receive events asynchronously, creating eventual consistency.

---

## 7. Adapter Pattern

### Location

**Payment Service → External Payment Gateway**

Different payment providers may expose different APIs.

SALESTORM uses an internal common interface:

```text
PaymentGateway
      |
      +---- PaymentProviderAAdapter
      |
      +---- PaymentProviderBAdapter
```

Each adapter converts the external provider API into the internal SALESTORM payment interface.

### Problem Solved

Hides provider-specific API formats from the rest of the application.

### Benefit

A payment provider can be replaced without changing the entire Payment Service.

### Trade-off

Each external provider requires an adapter and data-mapping logic.

---

## 8. Repository Pattern

### Location

**Inventory, Reservation, Payment and Order Services**

Example:

```text
InventoryService
       |
       v
InventoryRepository
       |
       v
Database
```

Repositories handle database operations such as:

```text
findInventory()
reserveInventory()
releaseInventory()
saveReservation()
findOrder()
savePayment()
```

### Problem Solved

Separates business logic from persistence/database operations.

### Benefit

The service does not need to directly depend on SQL/database implementation details.

### Trade-off

Adds interfaces and repository implementation classes.

---

## 9. Facade Pattern

### Location

**Purchase / Checkout Orchestration**

A purchase operation may involve several services:

```text
Client
  |
  v
Purchase Facade
  |
  +----> Inventory / Reservation
  |
  +----> Payment
  |
  +----> Order
```

The client interacts with a simplified purchase workflow instead of coordinating every service individually.

### Problem Solved

Hides the complexity of a multi-step purchase workflow.

### Trade-off

The Facade should remain focused on orchestration. If too much business logic is placed inside it, it can become a large and difficult-to-maintain component.

---

## 10. Circuit Breaker Pattern

### Location

**Payment Service → External Payment Gateway**

During a flash sale, an external payment provider may become slow or unavailable.

Instead of continuously sending requests:

```text
Payment Service
      |
      v
Circuit Breaker
      |
      v
Payment Gateway
```

The circuit breaker can move through states:

```text
CLOSED
  |
  | repeated failures
  v
OPEN
  |
  | wait/recovery period
  v
HALF-OPEN
  |
  | successful test
  v
CLOSED
```

### Problem Solved

Prevents repeated requests to a failing external dependency.

### Benefit

Protects SALESTORM from cascading failures and allows the system to fail fast.

### Trade-off

The failure threshold, timeout and recovery configuration must be carefully tuned.

---

## 11. Pattern Interaction in SALESTORM

The patterns work together rather than operating independently.

```text
                         SALESTORM
                             |
                    Purchase / Checkout
                             |
                           Facade
                             |
              +--------------+--------------+
              |                             |
        Reservation                     Payment
              |                             |
        Repository                     Strategy
              |                             |
          Inventory                    Factory
              |                             |
        Database                       Adapter
                                            |
                                      Circuit Breaker
                                            |
                                    External Gateway
              |
              v
       Domain Events
              |
           Observer
              |
       Message Broker
              |
       +------+------+------+
       |      |      |      |
     Order  Inventory  Notification
     Service Service    Service
       |
   Repository
       |
    Database
```

---

## 12. Why These Patterns Were Selected

The selected patterns directly support the main SALESTORM requirements:

| SALESTORM Requirement                  | Supporting Pattern                             |
| -------------------------------------- | ---------------------------------------------- |
| Multiple payment providers             | Strategy + Factory                             |
| External payment API integration       | Adapter                                        |
| Reservation lifecycle                  | State                                          |
| Order lifecycle                        | State                                          |
| Asynchronous service communication     | Observer                                       |
| Database separation                    | Repository                                     |
| Multi-step purchase workflow           | Facade                                         |
| Payment service failure protection     | Circuit Breaker                                |
| High-concurrency flash-sale processing | Repository + State + event-driven architecture |

These patterns are not introduced only for theoretical use. Each pattern addresses a specific architectural problem in the SALESTORM system.
