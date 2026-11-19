## ADDED Requirements

### Requirement: Render the guard name and status legibly
The raid view SHALL present the registered guard's name and current duty status legibly with supported separators.

#### Scenario: Latin and Chinese names
- **WHEN** a registered guard has a Latin or Chinese name and the player opens its warning or replay
- **THEN** the full name and duty status remain legible without a replacement glyph between them.
