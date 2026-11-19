## ADDED Requirements
### Requirement: A buildable radar station in the private base
The private base SHALL offer a two-by-one radar expedition station that consumes one power and opens the existing exploration, world map and raid-defense flows.
#### Scenario: Visit from the home map
- **WHEN** a commander taps their station and chooses a destination
- **THEN** the relevant existing game screen opens using that commander's current account and the return path leads back to their own base
### Requirement: Bounded advance signal for a scheduled private raid
A powered station SHALL display a server-clock estimate during the ninety minutes preceding the existing formal warning and SHALL respect offline protection.
#### Scenario: Monitor before formal warning
- **WHEN** the owner reads the station repeatedly within the advance signal window
- **THEN** the client shows minutes remaining to the warning without creating an encounter or changing its schedule, resources or rewards
#### Scenario: Power, recovery and warning transitions
- **WHEN** the station loses power, the raid clock awaits the owner, or an existing warning becomes active
- **THEN** the view reflects the appropriate state and only a formal warning offers the existing enemy and resource preview

