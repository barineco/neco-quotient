from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from types import MappingProxyType

@dataclass(frozen=True, init=False, eq=False)
class ResidualSet[R]:

    values: tuple[R, ...]

    def __init__(self, values) -> None:
        unique: list[R] = []
        for value in values:
            if not any(value == item for item in unique):
                unique.append(value)
        object.__setattr__(self, "values", tuple(unique))

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, ResidualSet):
            return NotImplemented
        return len(self.values) == len(other.values) and all(
            any(value == item for item in other.values) for value in self.values
        )

    def __iter__(self):
        return iter(self.values)

    def __repr__(self) -> str:
        return f"ResidualSet({self.values!r})"

@dataclass(frozen=True)
class SourceRef[S, Rev]:

    identity: S
    revision: Rev

@dataclass(frozen=True)
class WithinRuntime:

    name: str

@dataclass(frozen=True)
class CrossLanguage:

    name: str

type DigestScope = WithinRuntime | CrossLanguage

@dataclass(frozen=True)
class ProjectionDigest:

    digest: str
    scope: DigestScope

def _frozen_digests(digests: Mapping[str, ProjectionDigest]) -> Mapping[str, ProjectionDigest]:
    return MappingProxyType(dict(digests))

@dataclass(frozen=True)
class Certificate[S, Rev, C, Obs, R, E]:

    rule_revision: str
    source: SourceRef[S, Rev]
    coordinate: C
    digests: Mapping[str, ProjectionDigest]
    residuals: ResidualSet[R] | Iterable[R]
    observations: Obs
    evidence: E

    def __post_init__(self) -> None:
        object.__setattr__(self, "digests", _frozen_digests(self.digests))
        object.__setattr__(self, "residuals", ResidualSet(self.residuals))

@dataclass(frozen=True)
class Expected[S, Rev, C, Obs, R]:

    rule_revision: str
    source: SourceRef[S, Rev]
    coordinate: C
    observations: Obs
    residuals: ResidualSet[R] | Iterable[R]

    def __post_init__(self) -> None:
        object.__setattr__(self, "residuals", ResidualSet(self.residuals))
