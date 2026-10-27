use neco_quotient_encoding::{
    canonical_bytes, decode_canonical, normalize_digests, normalize_residuals, CertificateWire,
    DigestScope, EncodingFailure, JsonValue, ProjectionDigestWire, SourceRefWire,
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
        digests: vec![],
        residuals,
        observations: JsonValue::Null,
        evidence: JsonValue::Null,
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

fn digest(projection: &str, fill: char) -> ProjectionDigestWire {
    ProjectionDigestWire {
        projection: projection.into(),
        digest: fill.to_string().repeat(64),
        scope: DigestScope::WithinRuntime("rust".into()),
    }
}

#[test]
fn projection_digest_order_does_not_change_digest() -> Result<(), EncodingFailure> {
    let mut one = certificate(vec![]);
    one.digests = normalize_digests(vec![
        digest("p1", 'a'),
        digest("p3", 'c'),
        digest("p2", 'b'),
    ])?;
    let mut two = certificate(vec![]);
    two.digests = normalize_digests(vec![
        digest("p3", 'c'),
        digest("p2", 'b'),
        digest("p1", 'a'),
        digest("p2", 'b'),
    ])?;

    assert_eq!(one.canonical_bytes()?, two.canonical_bytes()?);
    assert_eq!(one.digest()?, two.digest()?);
    Ok(())
}
