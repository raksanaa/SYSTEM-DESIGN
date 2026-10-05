# SOLID Mapping

SALESTORM applies the SOLID principles to keep service responsibilities separated, extensible and maintainable.

| Principle                                 | SALESTORM Application                                                                                                                                                                                                                                 |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **SRP — Single Responsibility Principle** | Reservation, payment, order, inventory and notification components have separate responsibilities. `ReservationService` handles reservation logic, `PaymentService` handles payment processing, and `OrderService` handles order creation and status. |
| **OCP — Open/Closed Principle**           | New payment providers or payment strategies can be added behind the existing `PaymentProvider` abstraction without modifying the core payment business logic.                                                                                         |
| **LSP — Liskov Substitution Principle**   | Any implementation of the `PaymentProvider` interface should be replaceable without changing the behaviour expected by `PaymentService`.                                                                                                              |
| **ISP — Interface Segregation Principle** | Interfaces are kept focused on specific responsibilities, such as `PaymentProvider`, `InventoryRepository` and `NotificationService`, rather than using one large interface.                                                                          |
| **DIP — Dependency Inversion Principle**  | Business services depend on abstractions such as `PaymentProvider` and `InventoryRepository`, rather than directly depending on concrete payment gateways or database implementations.                                                                |

## SRP Example

The purchase workflow is divided into separate responsibilities:

```text
ReservationService
        |
        +---- InventoryRepository
        |
        +---- ReservationRepository

PaymentService
        |
        +---- PaymentProvider

OrderService
        |
        +---- OrderRepository

NotificationService
        |
        +---- NotificationProvider
```

Each component has a focused responsibility rather than one large service handling the complete workflow.

## OCP Example

`PaymentService` depends on the `PaymentProvider` abstraction.

```text
              PaymentProvider
                    |
          +---------+---------+
          |                   |
   PaymentProviderA    PaymentProviderB
```

A new payment provider can be introduced by implementing the existing interface.

The core payment business logic does not need to be rewritten.

## LSP Example

Any valid `PaymentProvider` implementation should support the operations expected by `PaymentService`.

For example:

```text
PaymentService
      |
      v
PaymentProvider
      |
      +---- Provider A
      |
      +---- Provider B
```

The concrete provider can be changed without changing the calling service.

## ISP Example

Instead of creating one large interface containing unrelated operations, SALESTORM uses focused interfaces.

Examples:

```text
PaymentProvider
InventoryRepository
NotificationProvider
OrderRepository
```

Each interface exposes only the operations required by its client.

## DIP Example

`PaymentService` should depend on:

```text
PaymentProvider
```

rather than directly depending on:

```text
StripeGateway
```

or another specific payment implementation.

Similarly, business services can depend on:

```text
InventoryRepository
```

rather than directly depending on a particular SQL/ORM implementation.

This allows infrastructure implementations to change without rewriting the business logic.

## SOLID Benefit to SALESTORM

Applying SOLID helps SALESTORM:

* Separate business responsibilities.
* Add new payment providers more easily.
* Replace infrastructure implementations.
* Reduce coupling between services.
* Improve unit-testability.
* Keep the flash-sale workflow maintainable as the system grows.

## Summary

```text
SRP → Separate responsibilities
OCP → Extend without modifying core logic
LSP → Implementations remain interchangeable
ISP → Keep interfaces focused
DIP → Depend on abstractions
```
