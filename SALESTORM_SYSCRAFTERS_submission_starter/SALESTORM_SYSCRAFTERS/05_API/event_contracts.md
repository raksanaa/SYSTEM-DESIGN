# API & Event Design

## Commands
- ReserveInventory
- ReleaseReservation
- ConfirmReservation
- StartPayment
- CreateOrder
- CancelOrder
- CreateShipment

## Events
- ReservationCreated
- ReservationReleased
- PaymentSucceeded
- PaymentFailed
- OrderConfirmed
- OrderCancelled
- ShipmentCreated
- ShipmentDelivered

## Event ownership
- Inventory Service owns reservation events.
- Payment Service owns payment events.
- Order Service owns order lifecycle events.
- Fulfilment owns shipment events.
- Notification consumes relevant events but does not mutate order state.

## Idempotency
Consumers store processed event IDs or use unique business keys.
