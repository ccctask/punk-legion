# independent-account-recovery Specification

## Purpose
让独立内测玩家在私人基地中为自己的账号生成单次恢复凭据，换机或遗忘密码后能从登录页重新掌握原有基地、机体和库存，并让原会话与已消费的凭据及时失效。

## Requirements

### Requirement: Issue and replace a personal recovery code
An authenticated owner SHALL be able to obtain a single-use recovery code after verifying the current password and explicitly requesting issuance or replacement.

#### Scenario: Replace a saved code
- **WHEN** an owner replaces an existing recovery code
- **THEN** the interface discloses the replacement once, the former code ceases to work and unrelated players retain their own credentials.

### Requirement: Recover an independent account on a clean device
The login entry SHALL allow a player with their account name and unused recovery code to set a new password for the original account.

#### Scenario: Recover once and resume play
- **WHEN** the code is successfully redeemed and the player enters with the new password
- **THEN** the player reaches the same private base and owned robot, preceding sessions are invalid and the code cannot be redeemed twice.
