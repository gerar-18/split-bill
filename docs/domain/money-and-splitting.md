# Money and Splitting Rules

## Money

Money must use a representation that avoids binary floating-point errors. The exact representation and currency policy will be finalized in M1.

## Supported split modes

- whole item;
- equal participants;
- percentage;
- quantity/portion.

## Allocation invariant

All allocated amounts must reconcile to the receipt total under the documented rounding policy.

## Edge cases

- zero-value item;
- one-cent item;
- odd cent distribution;
- large totals;
- percentage totals not equal to 100%;
- duplicate item names;
- quantity greater than one.
