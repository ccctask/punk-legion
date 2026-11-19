# owned-robot-workshop Specification

## Purpose
TBD - created by archiving change m09-android-workshop-reply-diagnosis. Update Purpose after archive.

## Requirements

### Requirement: Android workshop reply diagnosis evidence
The workshop failure investigation SHALL identify the actual HTTP request outcome with bounded diagnostic metadata and reconcile committed requests against their unique receipts.

#### Scenario: Build commits but the client cannot refresh
- **WHEN** a new test account submits a manufacture request and retries its original key after an uncertain result
- **THEN** the diagnostic record connects the client callback and response boundary without logging credentials, and reports whether one robot and one charge were produced.

### Requirement: Bounded confirmation recovery for workshop writes
The workshop SHALL preserve a design or build operation and retry its original key at most once automatically per confirmation round after an uncertain response, retaining a manual confirmation action when still uncertain.

#### Scenario: Manufacture committed before reply loss
- **WHEN** the service commits a manufacture and the response is lost
- **THEN** retrying the same operation confirms its original receipt and refreshes the actual hangar without another robot or charge.

#### Scenario: Continuous connection failure
- **WHEN** connection failures continue through the automatic retry
- **THEN** automatic requests stop, the client clearly marks the write result as unconfirmed and retains the same operation for manual recovery and relogin.

#### Scenario: Confirmed reply and business refusal
- **WHEN** the service returns either the matching operation receipt or an explicit business refusal
- **THEN** the client displays the confirmed result or refusal through the normal workshop flow and preserves existing refit behavior.

#### Scenario: Reply belongs to another otherwise identical manufacture
- **WHEN** a successful-looking response contains another operation's otherwise valid manufacture receipt
- **THEN** the client keeps its own pending operation unconfirmed unless the response-only confirmation key matches its original key and the receipt's action-specific fields match.
