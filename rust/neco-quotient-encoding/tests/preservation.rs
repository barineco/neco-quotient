use std::collections::BTreeMap;

use neco_quotient_encoding::{
    canonical_bytes, decode_canonical, normalize_residuals, CertificateWire, DigestScope,
    EncodingFailure, JsonValue, ProjectionDigestWire, SourceRefWire,
};

fn text(value: &str) -> JsonValue {
    JsonValue::String(value.into())
}

fn certificate(residuals: Vec<JsonValue>) -> CertificateWire {
    CertificateWire {
        rule_revision: "r".into(),
        source: SourceRefWire {
            identity: "s".into(),
            revision: "v".into(),
        },
        coordinate: JsonValue::Object(vec![("axis".into(), text("a"))]),
        digests: BTreeMap::new(),
        residuals,
        observations: JsonValue::Null,
        evidence: JsonValue::Null,
    }
}

fn digest(fill: char) -> ProjectionDigestWire {
    ProjectionDigestWire {
        digest: fill.to_string().repeat(64),
        scope: DigestScope::WithinRuntime("rust".into()),
    }
}

#[test]
fn decode_then_encode_preserves_bytes() -> Result<(), EncodingFailure> {
    let bytes = br#"{"a":["x",null,true],"b":{"c":"d"}}"#;
    let decoded = decode_canonical(bytes)?;
    assert_eq!(canonical_bytes(&decoded)?, bytes);
    Ok(())
}

#[test]
fn digest_names_are_read_from_object_keys_in_any_input_order() -> Result<(), EncodingFailure> {
    let entry = |fill: char| {
        JsonValue::Object(vec![
            ("digest".into(), text(&fill.to_string().repeat(64))),
            (
                "scope".into(),
                JsonValue::Object(vec![("within_runtime".into(), text("rust"))]),
            ),
        ])
    };
    let forward = JsonValue::Object(vec![
        ("p1".into(), entry('a')),
        ("p2".into(), entry('b')),
        ("p3".into(), entry('c')),
    ]);
    let reversed = JsonValue::Object(vec![
        ("p3".into(), entry('c')),
        ("p2".into(), entry('b')),
        ("p1".into(), entry('a')),
    ]);

    let mut one = certificate(vec![]).to_value()?;
    let mut two = certificate(vec![]).to_value()?;
    set_digests(&mut one, forward);
    set_digests(&mut two, reversed);

    let first = CertificateWire::from_value(&one)?;
    let second = CertificateWire::from_value(&two)?;
    assert_eq!(first, second);
    assert_eq!(first.canonical_bytes()?, second.canonical_bytes()?);
    assert_eq!(first.digest()?, second.digest()?);
    Ok(())
}

fn set_digests(value: &mut JsonValue, digests: JsonValue) {
    if let JsonValue::Object(fields) = value {
        for (name, child) in fields.iter_mut() {
            if name == "digests" {
                *child = digests.clone();
            }
        }
    }
}

#[test]
fn projection_digest_map_insertion_order_does_not_change_digest() -> Result<(), EncodingFailure> {
    let mut one = certificate(vec![]);
    one.digests.insert("p1".into(), digest('a'));
    one.digests.insert("p3".into(), digest('c'));
    one.digests.insert("p2".into(), digest('b'));
    let mut two = certificate(vec![]);
    two.digests.insert("p3".into(), digest('c'));
    two.digests.insert("p2".into(), digest('b'));
    two.digests.insert("p1".into(), digest('a'));

    assert_eq!(one.canonical_bytes()?, two.canonical_bytes()?);
    assert_eq!(one.digest()?, two.digest()?);
    Ok(())
}

#[test]
fn residual_order_does_not_change_digest() -> Result<(), EncodingFailure> {
    let first = JsonValue::Object(vec![("x".into(), text("1")), ("y".into(), text("2"))]);
    let first_permuted = JsonValue::Object(vec![("y".into(), text("2")), ("x".into(), text("1"))]);
    let second = JsonValue::Array(vec![text("z")]);

    let one = certificate(normalize_residuals(vec![
        first.clone(),
        second.clone(),
        first_permuted.clone(),
    ])?);
    let two = certificate(normalize_residuals(vec![second, first_permuted, first])?);

    assert_eq!(one.canonical_bytes()?, two.canonical_bytes()?);
    assert_eq!(one.digest()?, two.digest()?);
    Ok(())
}

#[test]
fn digest_object_bytes_are_canonical_without_renormalization() -> Result<(), EncodingFailure> {
    let mut wire = certificate(vec![]);
    wire.digests.insert("p2".into(), digest('b'));
    wire.digests.insert("p1".into(), digest('a'));
    let bytes = wire.canonical_bytes()?;
    let decoded = decode_canonical(&bytes)?;
    assert_eq!(canonical_bytes(&decoded)?, bytes);
    Ok(())
}
