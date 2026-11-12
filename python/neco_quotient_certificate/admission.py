from collections.abc import Callable, Mapping
from types import MappingProxyType

from .certificate import Certificate, Expected, ProjectionDigest, SourceRef, _frozen_digests
from .checked import _CHECK_SEAL, Checked
from .checks import (
    AdmissionChecks,
    CheckMatched,
    CheckMismatched,
    CheckResult,
    Condition,
    DigestChecks,
    Prerequisite,
    PrerequisiteEstablished,
    PrerequisiteFailed,
    ProjectionCertificateOnly,
    ProjectionDifferent,
    ProjectionMatched,
    ProjectionRecomputedOnly,
    ProjectionResult,
    SourceChecks,
)
from .failure import ConditionFailure, Mismatch, Origin, _MISMATCH_SEAL
from .rule import Rule, RuleTable

OPERATION = "admit"
TABLE_EXPECTATION = "rule in table"

def check[S, Rev, C, Obs, R, E, P](
    table: RuleTable[S, Rev, C, Obs, E],
    certificate: Certificate[S, Rev, C, Obs, R, E],
    expected: Expected[S, Rev, C, Obs, R],
    provenance: P,
) -> AdmissionChecks[P]:
    checks, _ = _evaluate(table, certificate, expected, provenance)
    return checks

def admit[S, Rev, C, Obs, R, E, P](
    table: RuleTable[S, Rev, C, Obs, E],
    certificate: Certificate[S, Rev, C, Obs, R, E],
    expected: Expected[S, Rev, C, Obs, R],
    provenance: P,
) -> Checked[S, Rev, C, Obs, R, E] | Mismatch[P]:
    checks, recomputed = _evaluate(table, certificate, expected, provenance)
    if recomputed is not None and checks.all_matched():
        return Checked(
            certificate=certificate,
            expected=expected,
            recomputed=recomputed,
            _table=table,
            _seal=_CHECK_SEAL,
        )
    return Mismatch(checks=checks, _seal=_MISMATCH_SEAL)

def _evaluate[S, Rev, C, Obs, R, E, P](
    table: RuleTable[S, Rev, C, Obs, E],
    certificate: Certificate[S, Rev, C, Obs, R, E],
    expected: Expected[S, Rev, C, Obs, R],
    provenance: P,
) -> tuple[AdmissionChecks[P], Mapping[str, ProjectionDigest] | None]:
    origin = _origin_of(certificate)
    selected = _select_rule(table, certificate, expected, origin, provenance)
    if isinstance(selected, ConditionFailure):
        decode = PrerequisiteFailed(selected)
        recomputed = None
    else:
        recomputed = _frozen_digests(
            selected(
                certificate.source,
                certificate.coordinate,
                certificate.observations,
                certificate.evidence,
            )
        )
        decode = PrerequisiteEstablished(_compare_digests(recomputed, certificate.digests))
    source = _source_branch(certificate, expected, origin, provenance)
    return AdmissionChecks(origin=origin, provenance=provenance, decode=decode, source=source), recomputed

def _origin_of(certificate: Certificate) -> Origin:
    return Origin(
        rule_revision=certificate.rule_revision,
        source_identity=str(certificate.source.identity),
        source_revision=str(certificate.source.revision),
    )

def _select_rule[S, Rev, C, Obs, R, E, P](
    table: RuleTable[S, Rev, C, Obs, E],
    certificate: Certificate[S, Rev, C, Obs, R, E],
    expected: Expected[S, Rev, C, Obs, R],
    origin: Origin,
    provenance: P,
) -> Rule[S, Rev, C, Obs, E] | ConditionFailure[P]:
    if certificate.rule_revision != expected.rule_revision:
        return _failure(Condition.DECODE, expected.rule_revision, certificate.rule_revision, origin, provenance)
    rule = table.lookup(certificate.rule_revision)
    if rule is None:
        return _failure(Condition.DECODE, TABLE_EXPECTATION, certificate.rule_revision, origin, provenance)
    return rule

def _compare_digests(
    recomputed: Mapping[str, ProjectionDigest],
    certificate: Mapping[str, ProjectionDigest],
) -> DigestChecks:
    checks: dict[str, ProjectionResult] = {}
    for name in sorted(set(recomputed) | set(certificate)):
        checks[name] = _projection_result(recomputed.get(name), certificate.get(name))
    return MappingProxyType(checks)

def _projection_result(
    expected: ProjectionDigest | None,
    actual: ProjectionDigest | None,
) -> ProjectionResult:
    if expected is None:
        if actual is None:
            raise ValueError("projection is absent on both sides")
        return ProjectionCertificateOnly(actual)
    if actual is None:
        return ProjectionRecomputedOnly(expected)
    if expected == actual:
        return ProjectionMatched(expected)
    return ProjectionDifferent(expected=expected, actual=actual)

def _source_branch[S, Rev, C, Obs, R, E, P](
    certificate: Certificate[S, Rev, C, Obs, R, E],
    expected: Expected[S, Rev, C, Obs, R],
    origin: Origin,
    provenance: P,
) -> Prerequisite[ConditionFailure[P], SourceChecks[P]]:
    if certificate.source != expected.source:
        return PrerequisiteFailed(
            _failure(Condition.SOURCE, _source_text(expected.source), _source_text(certificate.source), origin, provenance)
        )
    return PrerequisiteEstablished(
        SourceChecks(
            coordinate=_condition_result(
                certificate.coordinate == expected.coordinate,
                lambda: _failure(
                    Condition.COORDINATE, repr(expected.coordinate), repr(certificate.coordinate), origin, provenance
                ),
            ),
            observations=_condition_result(
                certificate.observations == expected.observations,
                lambda: _failure(
                    Condition.OBSERVATIONS, repr(expected.observations), repr(certificate.observations), origin, provenance
                ),
            ),
            residual=_condition_result(
                certificate.residuals == expected.residuals,
                lambda: _failure(
                    Condition.RESIDUAL, repr(expected.residuals), repr(certificate.residuals), origin, provenance
                ),
            ),
        )
    )

def _condition_result[F](holds: bool, failure: Callable[[], F]) -> CheckResult[F]:
    if holds:
        return CheckMatched()
    return CheckMismatched(failure())

def _failure[P](condition: Condition, expected: str, actual: str, origin: Origin, provenance: P) -> ConditionFailure[P]:
    return ConditionFailure(
        condition=condition,
        operation=OPERATION,
        expected=expected,
        actual=actual,
        origin=origin,
        provenance=provenance,
    )

def _source_text[S, Rev](source: SourceRef[S, Rev]) -> str:
    return f"{source.identity}@{source.revision}"
