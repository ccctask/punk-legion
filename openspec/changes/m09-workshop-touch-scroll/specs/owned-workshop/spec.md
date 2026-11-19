# owned-workshop Delta

## ADDED Requirements

### Requirement: Browse workshop controls by touch without unintended actions
The workshop SHALL allow touch dragging from its scroll-content buttons and option selectors to browse the panel without activating those controls or changing the selected option. Ordinary taps SHALL retain their existing action or option selection, and disabled controls SHALL remain unavailable.

#### Scenario: Drag across an action button
- **WHEN** the commander drags from a workshop action button beyond the scrolling threshold
- **THEN** the panel scrolls and the button submits no action

#### Scenario: Drag across an option selector
- **WHEN** the commander drags from a workshop option selector beyond the scrolling threshold
- **THEN** the panel scrolls without opening its menu or changing its selected item

#### Scenario: Tap an available control
- **WHEN** the commander taps an available action button or opens a selector and chooses an item
- **THEN** the original action or selection occurs exactly once

#### Scenario: Preserve editing and unavailable controls
- **WHEN** the commander edits a workshop name or attempts to use a disabled control
- **THEN** text editing retains its normal behavior and the unavailable control submits no action
