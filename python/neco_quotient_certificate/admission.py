from .certificate import Certificate, Expected, SourceRef
from .checked import _CHECK_SEAL, Checked
from .failure import Mismatch, Origin, Stage
from .rule import RuleTable


OPERATION = "admit"
TABLE_EXPECTATION = "rule in table"


def admit[S, Rev, C, Obs, R, E, P](
    table: RuleTable[S, Rev, C, Obs, E],
    certificate: Certificate[S, Rev, C, Obs, R, E],
    expected: Expected[S, Rev, C, Obs, R],
    provenance: P,
) -> Checked[S, Rev, C, Obs, R, E] | Mismatch[P]:
    """証明書を期待値と照合する。

    段階はリビジョン、表の検索、source、coordinate、observations、digest、residual の順に検査し、
    最初に成立しなかった段階の不一致を返す。リビジョンの比較は表の検索より先に行う。
    """
    if certificate.rule_revision != expected.rule_revision:
        return _mismatch(
            certificate,
            "decode",
            expected.rule_revision,
            certificate.rule_revision,
            provenance,
        )
    rule = table.lookup(certificate.rule_revision)
    if rule is None:
        return _mismatch(
            certificate,
            "decode",
            TABLE_EXPECTATION,
            certificate.rule_revision,
            provenance,
        )
    if certificate.source != expected.source:
        return _mismatch(
            certificate,
            "source",
            _source_text(expected.source),
            _source_text(certificate.source),
            provenance,
        )
    if certificate.coordinate != expected.coordinate:
        return _mismatch(
            certificate,
            "coordinate",
            repr(expected.coordinate),
            repr(certificate.coordinate),
            provenance,
        )
    if certificate.observations != expected.observations:
        return _mismatch(
            certificate,
            "observations",
            repr(expected.observations),
            repr(certificate.observations),
            provenance,
        )
    recomputed = tuple(
        rule(
            certificate.source,
            certificate.coordinate,
            certificate.observations,
            certificate.evidence,
        )
    )
    if certificate.digests != recomputed:
        return _mismatch(
            certificate,
            "digest",
            repr(recomputed),
            repr(certificate.digests),
            provenance,
        )
    if certificate.residuals != expected.residuals:
        return _mismatch(
            certificate,
            "residual",
            repr(expected.residuals),
            repr(certificate.residuals),
            provenance,
        )
    return Checked(
        certificate=certificate,
        recomputed=recomputed,
        _table=table,
        _seal=_CHECK_SEAL,
    )


def _source_text[S, Rev](source: SourceRef[S, Rev]) -> str:
    return f"{source.identity}@{source.revision}"


def _mismatch[S, Rev, C, Obs, R, E, P](
    certificate: Certificate[S, Rev, C, Obs, R, E],
    stage: Stage,
    expected: str,
    actual: str,
    provenance: P,
) -> Mismatch[P]:
    return Mismatch(
        operation=OPERATION,
        stage=stage,
        expected=expected,
        actual=actual,
        origin=Origin(
            rule_revision=certificate.rule_revision,
            source_identity=str(certificate.source.identity),
            source_revision=str(certificate.source.revision),
        ),
        provenance=provenance,
        contributing=(),
    )
