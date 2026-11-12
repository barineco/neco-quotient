from dataclasses import InitVar, dataclass, field
from .checks import AdmissionChecks, Condition, Status

_MISMATCH_SEAL = object()

@dataclass(frozen=True)
class Origin:

    rule_revision: str
    source_identity: str
    source_revision: str

@dataclass(frozen=True)
class ConditionFailure[P]:

    condition: Condition
    operation: str
    expected: str
    actual: str
    origin: Origin
    provenance: P

@dataclass(frozen=True)
class Mismatch[P]:

    checks: AdmissionChecks[P]
    _seal: InitVar[object | None] = field(default=None)

    def __post_init__(self, _seal: object | None) -> None:
        if _seal is not _MISMATCH_SEAL:
            raise TypeError("Mismatch は admit だけが構築する")
        if self.checks.all_matched():
            raise ValueError("Mismatch は不一致となった条件を一つ以上持つ必要がある")

    @property
    def origin(self) -> Origin:
        return self.checks.origin

    @property
    def provenance(self) -> P:
        return self.checks.provenance

    def status_at(self, condition: Condition) -> Status[P]:
        return self.checks.status_at(condition)
