use neco_quotient_encoding::{
    canonical_bytes, decode_canonical, CertificateWire, DigestScope, EncodingFailure, JsonValue,
    ProjectionDigestWire, SourceRefWire,
};

fn sample() -> CertificateWire {
    CertificateWire {
        rule_revision: "rule-r1".into(),
        source: SourceRefWire {
            identity: "source-a".into(),
            revision: "rev-1".into(),
        },
        coordinate: JsonValue::Object(vec![
            ("axis".into(), JsonValue::String("a".into())),
            (
                "zone".into(),
                JsonValue::Array(vec![JsonValue::Null, JsonValue::Bool(true)]),
            ),
        ]),
        digests: vec![
            ProjectionDigestWire {
                projection: "p1".into(),
                digest: "0".repeat(64),
                scope: DigestScope::WithinRuntime("rust".into()),
            },
            ProjectionDigestWire {
                projection: "p2".into(),
                digest: "f".repeat(64),
                scope: DigestScope::CrossLanguage("scheme-1".into()),
            },
        ],
        residuals: vec![JsonValue::Object(vec![
            ("a".into(), JsonValue::String("1".into())),
            ("b".into(), JsonValue::String("2".into())),
        ])],
        observations: JsonValue::Object(vec![
            ("count".into(), JsonValue::String("2".into())),
            ("unit".into(), JsonValue::String("m".into())),
        ]),
        evidence: JsonValue::Array(vec![JsonValue::Object(vec![
            ("id".into(), JsonValue::String("e1".into())),
            ("kind".into(), JsonValue::String("k".into())),
        ])]),
    }
}

#[test]
fn certificate_survives_value_and_bytes_roundtrip() -> Result<(), EncodingFailure> {
    let original = sample();
    let bytes = canonical_bytes(&original.to_value()?)?;
    let decoded = decode_canonical(&bytes)?;
    let restored = CertificateWire::from_value(&decoded)?;
    assert_eq!(restored, original);
    Ok(())
}

#[test]
fn unsorted_coordinate_keys_survive_bytes_roundtrip() -> Result<(), EncodingFailure> {
    let mut original = sample();
    original.coordinate = JsonValue::Object(vec![
        ("zeta".into(), JsonValue::String("z".into())),
        ("alpha".into(), JsonValue::String("a".into())),
    ]);
    let bytes = original.canonical_bytes()?;
    let decoded = decode_canonical(&bytes)?;
    let restored = CertificateWire::from_value(&decoded)?;
    assert_eq!(restored.canonical_bytes()?, bytes);
    Ok(())
}
