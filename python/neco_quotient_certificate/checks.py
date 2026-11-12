from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from types import MappingProxyType
from typing import TYPE_CHECKING, Mapping

from .certificate import ProjectionDigest

if TYPE_CHECKING:
    from .failure import ConditionFailure, Origin

class Condition(StrEnum):

    DECODE = "decode"
    SOURCE = "source"
    COORDINATE = "coordinate"
    OBSERVATIONS = "observations"
    DIGEST = "digest"
    RESIDUAL = "residual"

    def prerequisite(self) -> Condition | None:
        return _PREREQUISITES.get(self)

_PREREQUISITES: Mapping[Condition, Condition] = MappingProxyType(
    {
        Condition.DIGEST: Condition.DECODE,
        Condition.COORDINATE: Condition.SOURCE,
        Condition.OBSERVATIONS: Condition.SOURCE,
        Condition.RESIDUAL: Condition.SOURCE,
    }
)

@dataclass(frozen=True)
class PrerequisiteFailed[F]:

    failure: F

@dataclass(frozen=True)
class PrerequisiteEstablished[C]:

    children: C

type Prerequisite[F, C] = PrerequisiteFailed[F] | PrerequisiteEstablished[C]

@dataclass(frozen=True)
class CheckMatched:

    pass

@dataclass(frozen=True)
class CheckMismatched[F]:

    failure: F

type CheckResult[F] = CheckMatched | CheckMismatched[F]

@dataclass(frozen=True)
class ProjectionMatched:

    value: ProjectionDigest

@dataclass(frozen=True)
class ProjectionCertificateOnly:

    actual: ProjectionDigest

@dataclass(frozen=True)
class ProjectionRecomputedOnly:

    expected: ProjectionDigest

@dataclass(frozen=True)
class ProjectionDifferent:

    expected: ProjectionDigest
    actual: ProjectionDigest

type ProjectionResult = (
    ProjectionMatched | ProjectionCertificateOnly | ProjectionRecomputedOnly | ProjectionDifferent
)

type DigestChecks = Mapping[str, ProjectionResult]

def is_projection_matched(result: ProjectionResult) -> bool:
    return isinstance(result, ProjectionMatched)

def is_check_matched(result: CheckResult[object]) -> bool:
    return isinstance(result, CheckMatched)

@dataclass(frozen=True)
class SourceChecks[P]:

    coordinate: CheckResult[ConditionFailure[P]]
    observations: CheckResult[ConditionFailure[P]]
    residual: CheckResult[ConditionFailure[P]]

    def all_matched(self) -> bool:
        return (
            is_check_matched(self.coordinate)
            and is_check_matched(self.observations)
            and is_check_matched(self.residual)
        )

@dataclass(frozen=True)
class Matched:

    pass

@dataclass(frozen=True)
class Mismatched:

    pass

@dataclass(frozen=True)
class UncheckedByDecode[P]:

    failure: ConditionFailure[P]

@dataclass(frozen=True)
class UncheckedBySource[P]:

    failure: ConditionFailure[P]

type Status[P] = Matched | Mismatched | UncheckedByDecode[P] | UncheckedBySource[P]

def _status_of(matched: bool) -> Matched | Mismatched:
    return Matched() if matched else Mismatched()

@dataclass(frozen=True)
class AdmissionChecks[P]:

    origin: Origin
    provenance: P
    decode: Prerequisite[ConditionFailure[P], DigestChecks]
    source: Prerequisite[ConditionFailure[P], SourceChecks[P]]

    def all_matched(self) -> bool:
        decode = (
            isinstance(self.decode, PrerequisiteEstablished)
            and all(is_projection_matched(result) for result in self.decode.children.values())
        )
        source = (
            isinstance(self.source, PrerequisiteEstablished)
            and self.source.children.all_matched()
        )
        return decode and source

    def status_at(self, condition: Condition) -> Status[P]:
        if not isinstance(condition, Condition):
            raise ValueError(f"unknown condition {condition!r}")
        if condition is Condition.DECODE:
            return _status_of(isinstance(self.decode, PrerequisiteEstablished))
        if condition is Condition.SOURCE:
            return _status_of(isinstance(self.source, PrerequisiteEstablished))
        if condition is Condition.DIGEST:
            match self.decode:
                case PrerequisiteFailed(failure=failure):
                    return UncheckedByDecode(failure)
                case PrerequisiteEstablished(children=children):
                    return _status_of(
                        all(is_projection_matched(result) for result in children.values())
                    )
        match self.source:
            case PrerequisiteFailed(failure=failure):
                return UncheckedBySource(failure)
            case PrerequisiteEstablished(children=children):
                return _status_of(_source_child_matched(children, condition))
        raise ValueError(f"unknown condition {condition!r}")

def _source_child_matched(children: SourceChecks[object], condition: Condition) -> bool:
    if condition is Condition.COORDINATE:
        return is_check_matched(children.coordinate)
    if condition is Condition.OBSERVATIONS:
        return is_check_matched(children.observations)
    if condition is Condition.RESIDUAL:
        return is_check_matched(children.residual)
    raise ValueError(f"{condition!r} is not a source child")
