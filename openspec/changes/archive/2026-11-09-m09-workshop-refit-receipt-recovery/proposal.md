## Why
Signed build 1062 installed the right core on the server, yet the garage continued displaying the previous fit until the player scrolled to a separate manual retry. An ambiguous reply needs a visible path back to the real equipped state.

## What Changes
Recover a lost single-part refit reply with a bounded automatic same-key retry, and surface pending or unresolved status beside the selected item. Give initial garage reads a bounded retry and a visible failure action.

## Capabilities
### Modified Capabilities
- owned-workshop

## Impact
Owned workshop client and fresh-account tests; relies on the existing idempotent refit ledger.
