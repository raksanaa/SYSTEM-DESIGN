# AI Usage Note / Prompt Summary

## AI Tools Used

* ChatGPT / institution-approved AI tools.

## Purpose

AI tools were used to assist with:

* Drafting UML/Mermaid documentation after the architecture was selected.
* Generating a small concurrency simulation.
* Generating test cases and documentation structure.
* Reviewing edge cases and failure scenarios.
* Reviewing the architecture for consistency and completeness.

## Human Decisions

The team independently selected and defended the following architectural decisions:

* Service boundaries.
* SQL as the inventory source of truth.
* Atomic conditional inventory update.
* Admission/queue strategy.
* Idempotency for reservation and payment commands.
* Asynchronous payment-to-order recovery.
* Transactional outbox and event reliability.
* Security and observability decisions.
* Concurrency-control strategy and its trade-offs.

AI-generated suggestions were treated as supporting material. Final architectural decisions were made by the team based on the problem requirements.

## Validation

AI-generated artefacts were reviewed and tested by the team before demonstration.

The team checked:

* Inventory overselling scenarios.
* Duplicate request handling.
* Reservation expiry.
* Payment failure and timeout scenarios.
* Order Service failure and recovery.
* Retry and idempotency behaviour.
* Concurrency simulation results.
* Consistency between the architecture, database design, APIs and reliability mechanisms.

## Human Ownership

Every team member is responsible for understanding the generated artefacts and being able to explain the design decisions during evaluation.

The team retains ownership of the final architecture, documentation, diagrams and validation results.

## Transparency

AI was used as an assistance and validation tool, not as a replacement for architectural decision-making.

The final submission was reviewed by the team before demonstration.
