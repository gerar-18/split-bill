# Testing Strategy

## Unit tests

Business-critical behavior must be covered independently from UI and infrastructure:

- money arithmetic;
- equal splits;
- shared items;
- percentage splits;
- quantity splits;
- tax allocation;
- tip allocation;
- rounding;
- total invariants.

## Integration tests

Add when persistence and backend boundaries are introduced.

## UI tests

Cover critical user journeys rather than every visual detail.

## OCR evaluation

Maintain a fixture dataset under `tests/fixtures/receipts/` and measure extraction accuracy rather than relying on a few manual examples.

## Core invariant

For every valid completed receipt:

`sum(person totals) == receipt total`

subject to the documented rounding policy.
