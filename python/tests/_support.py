import dataclasses
from pathlib import Path

from neco_quotient_certificate import (
    Certificate,
    Condition,
    CrossLanguage,
    Expected,
    ProjectionDigest,
    RuleTable,
    SourceRef,
)

REVISION = "rule@1"
CONDITIONS = tuple(Condition)
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
COMPARISON_DIR = REPOSITORY_ROOT / "comparison" / "certificate-admit"

def sample_rule(source, coordinate, observations, evidence):
    digest = f"{source.identity}:{source.revision}:{coordinate}:{observations}:{evidence}"
    return {"evidence": ProjectionDigest(digest, CrossLanguage("sha256"))}

def sample_certificate():
    return Certificate(
        rule_revision=REVISION,
        source=SourceRef("source-alpha", "rev-1"),
        coordinate="coord-a",
        digests=sample_rule(
            SourceRef("source-alpha", "rev-1"), "coord-a", "observations-a", "evidence-a"
        ),
        residuals=("residual-a", "residual-b"),
        observations="observations-a",
        evidence="evidence-a",
    )

def sample_expected():
    return Expected(
        rule_revision=REVISION,
        source=SourceRef("source-alpha", "rev-1"),
        coordinate="coord-a",
        observations="observations-a",
        residuals=("residual-a", "residual-b"),
    )

def sample_table():
    table = RuleTable.of([(REVISION, sample_rule)])
    assert isinstance(table, RuleTable)
    return table

def break_condition(certificate, condition):
    if condition is Condition.SOURCE:
        return dataclasses.replace(certificate, source=SourceRef("source-beta", "rev-1"))
    if condition is Condition.COORDINATE:
        return dataclasses.replace(certificate, coordinate="coord-b")
    if condition is Condition.OBSERVATIONS:
        return dataclasses.replace(certificate, observations="observations-b")
    if condition is Condition.DIGEST:
        return dataclasses.replace(
            certificate,
            digests={"evidence": ProjectionDigest("tampered", CrossLanguage("sha256"))},
        )
    if condition is Condition.RESIDUAL:
        return dataclasses.replace(certificate, residuals=("residual-c",))
    raise ValueError(f"no break for condition {condition}")

def reference_write_string(text):
    out = bytearray(b'"')
    for character in text:
        code = ord(character)
        if character == '"':
            out += b'\\"'
        elif character == "\\":
            out += b"\\\\"
        elif code == 0x08:
            out += b"\\b"
        elif code == 0x0C:
            out += b"\\f"
        elif character == "\n":
            out += b"\\n"
        elif character == "\r":
            out += b"\\r"
        elif character == "\t":
            out += b"\\t"
        elif code < 0x20:
            out += f"\\u{code:04x}".encode("ascii")
        else:
            out += character.encode("utf-8")
    out += b'"'
    return bytes(out)
