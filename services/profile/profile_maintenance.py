"""Request-scoped maintenance orchestration; the caller owns the transaction."""
import service_record
import recovery
import party
import expedition
import camp
import friends
import treasure
import raids


def advance_request_state(db):
    """Advance domains in commit-sensitive order without owning their rules."""
    service_record.expire(db)
    recovery.complete_due(db)
    party.expire(db)
    expedition.expire(db)
    camp.expire(db)
    friends.expire(db)
    treasure.expire(db)
    raids.due_accounts(db)
