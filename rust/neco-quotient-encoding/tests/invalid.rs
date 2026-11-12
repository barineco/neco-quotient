use std::collections::BTreeMap;

use neco_quotient_encoding::{
    decode_canonical, CertificateWire, EncodingCondition, EncodingFailure, JsonValue, SourceRefWire,
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
        coordinate: JsonValue::Null,
        digests: BTreeMap::new(),
        residuals,
        observations: JsonValue::Null,
        evidence: JsonValue::Null,
    }
}

fn digest_value(fill: char) -> JsonValue {
    JsonValue::Object(vec![
        ("digest".into(), text(&fill.to_string().repeat(64))),
        (
            "scope".into(),
            JsonValue::Object(vec![("within_runtime".into(), text("rust"))]),
        ),
    ])
}

fn set_field(value: &mut JsonValue, key: &str, replacement: JsonValue) {
    if let JsonValue::Object(fields) = value {
        for (name, child) in fields.iter_mut() {
            if name == key {
                *child = replacement.clone();
            }
        }
    }
}

#[test]
fn number_in_decoded_bytes_is_rejected() -> Result<(), EncodingFailure> {
    let result = decode_canonical(br#"{"n":1}"#);
    assert_eq!(
        result.err().map(|failure| failure.condition_name()),
        Some("number_not_canonical")
    );
    Ok(())
}

#[test]
fn non_canonical_escape_is_rejected() -> Result<(), EncodingFailure> {
    let result = decode_canonical(b"{\"a\":\"\\u0041\"}");
    assert_eq!(
        result.err().map(|failure| failure.condition_name()),
        Some("not_canonical")
    );
    Ok(())
}

#[test]
fn duplicate_key_is_rejected_by_decode() -> Result<(), EncodingFailure> {
    let decoded = decode_canonical(br#"{"a":"x","a":"y"}"#);
    assert_eq!(
        decoded.err().map(|failure| failure.condition_name()),
        Some("duplicate_key")
    );
    Ok(())
}

#[test]
fn whitespace_is_not_canonical() -> Result<(), EncodingFailure> {
    let result = decode_canonical(b"{ \"a\":\"b\"}");
    assert_eq!(
        result.err().map(|failure| failure.condition_name()),
        Some("not_canonical")
    );
    Ok(())
}

#[test]
fn unsorted_keys_are_not_canonical() -> Result<(), EncodingFailure> {
    let result = decode_canonical(br#"{"b":"x","a":"y"}"#);
    assert_eq!(
        result.err().map(|failure| failure.condition_name()),
        Some("not_canonical")
    );
    Ok(())
}

#[test]
fn missing_field_is_reported() -> Result<(), EncodingFailure> {
    let value = JsonValue::Object(vec![
        ("rule_revision".into(), text("r")),
        (
            "source".into(),
            JsonValue::Object(vec![
                ("identity".into(), text("s")),
                ("revision".into(), text("v")),
            ]),
        ),
        ("coordinate".into(), JsonValue::Null),
        ("digests".into(), JsonValue::Object(vec![])),
        ("residuals".into(), JsonValue::Array(vec![])),
        ("evidence".into(), JsonValue::Null),
    ]);
    let result = CertificateWire::from_value(&value);
    assert!(matches!(
        result,
        Err(EncodingFailure {
            operation: "from_value",
            condition: EncodingCondition::MissingField {
                field: "observations"
            },
            ..
        })
    ));
    Ok(())
}

#[test]
fn unknown_field_is_rejected_by_from_value() -> Result<(), EncodingFailure> {
    let mut value = certificate(vec![]).to_value()?;
    if let JsonValue::Object(fields) = &mut value {
        fields.push(("extra".into(), JsonValue::Null));
    }
    let result = CertificateWire::from_value(&value);
    assert!(matches!(
        result,
        Err(EncodingFailure {
            condition: EncodingCondition::UnknownField { ref field },
            ..
        }) if field == "extra"
    ));
    Ok(())
}

#[test]
fn unexpected_shape_reports_observed_kind() -> Result<(), EncodingFailure> {
    let mut value = certificate(vec![]).to_value()?;
    if let JsonValue::Object(fields) = &mut value {
        for (key, child) in fields.iter_mut() {
            if key == "rule_revision" {
                *child = JsonValue::Number(1.0);
            }
        }
    }
    let result = CertificateWire::from_value(&value);
    assert!(matches!(
        result,
        Err(EncodingFailure {
            operation: "from_value",
            condition: EncodingCondition::UnexpectedShape { ref actual, .. },
            ..
        }) if actual == "number"
    ));
    Ok(())
}

#[test]
fn non_normal_residuals_are_rejected_by_to_value() -> Result<(), EncodingFailure> {
    let unsorted = vec![
        JsonValue::Object(vec![("b".into(), text("2"))]),
        JsonValue::Object(vec![("a".into(), text("1"))]),
    ];
    let result = certificate(unsorted).to_value();
    assert_eq!(
        result.err().map(|failure| failure.condition_name()),
        Some("residuals_not_normalized")
    );
    Ok(())
}

#[test]
fn duplicate_key_certificate_is_rejected_by_from_value() -> Result<(), EncodingFailure> {
    let mut value = certificate(vec![]).to_value()?;
    if let JsonValue::Object(fields) = &mut value {
        fields.push(("rule_revision".into(), text("other")));
    }
    let result = CertificateWire::from_value(&value);
    assert!(matches!(
        result,
        Err(EncodingFailure {
            operation: "from_value",
            condition: EncodingCondition::DuplicateKey { ref key, .. },
            ..
        }) if key == "rule_revision"
    ));
    Ok(())
}

#[test]
fn non_normal_residuals_are_rejected_by_from_value() -> Result<(), EncodingFailure> {
    let mut value = certificate(vec![]).to_value()?;
    set_field(
        &mut value,
        "residuals",
        JsonValue::Array(vec![
            JsonValue::Object(vec![("b".into(), text("2"))]),
            JsonValue::Object(vec![("a".into(), text("1"))]),
        ]),
    );
    let result = CertificateWire::from_value(&value);
    assert!(matches!(
        result,
        Err(EncodingFailure {
            operation: "from_value",
            condition: EncodingCondition::ResidualsNotNormalized { .. },
            ..
        })
    ));
    Ok(())
}

#[test]
fn number_in_coordinate_is_rejected_by_from_value() -> Result<(), EncodingFailure> {
    let mut value = certificate(vec![]).to_value()?;
    set_field(
        &mut value,
        "coordinate",
        JsonValue::Object(vec![("n".into(), JsonValue::Number(2.5))]),
    );
    let result = CertificateWire::from_value(&value);
    assert!(matches!(
        result,
        Err(EncodingFailure {
            operation: "from_value",
            condition: EncodingCondition::NumberNotCanonical { .. },
            ..
        })
    ));
    Ok(())
}

#[test]
fn digests_as_array_are_rejected_by_from_value() -> Result<(), EncodingFailure> {
    let mut value = certificate(vec![]).to_value()?;
    set_field(
        &mut value,
        "digests",
        JsonValue::Array(vec![JsonValue::Object(vec![
            ("digest".into(), text(&"a".repeat(64))),
            ("projection".into(), text("p1")),
            (
                "scope".into(),
                JsonValue::Object(vec![("within_runtime".into(), text("rust"))]),
            ),
        ])]),
    );
    let result = CertificateWire::from_value(&value);
    assert!(matches!(
        result,
        Err(EncodingFailure {
            operation: "from_value",
            condition: EncodingCondition::UnexpectedShape {
                field: "digests",
                expected: "object",
                ..
            },
            ..
        })
    ));
    Ok(())
}

#[test]
fn duplicate_digest_name_is_rejected_before_map_conversion() -> Result<(), EncodingFailure> {
    let mut value = certificate(vec![]).to_value()?;
    set_field(
        &mut value,
        "digests",
        JsonValue::Object(vec![
            ("p1".into(), digest_value('a')),
            ("p1".into(), digest_value('b')),
        ]),
    );
    let result = CertificateWire::from_value(&value);
    assert!(matches!(
        result,
        Err(EncodingFailure {
            operation: "from_value",
            condition: EncodingCondition::DuplicateKey { ref path, ref key },
            ..
        }) if path == "digests" && key == "p1"
    ));
    Ok(())
}

#[test]
fn projection_field_inside_a_digest_entry_is_rejected() -> Result<(), EncodingFailure> {
    let mut entry = digest_value('a');
    if let JsonValue::Object(fields) = &mut entry {
        fields.push(("projection".into(), text("p1")));
    }
    let mut value = certificate(vec![]).to_value()?;
    set_field(
        &mut value,
        "digests",
        JsonValue::Object(vec![("p1".into(), entry)]),
    );
    let result = CertificateWire::from_value(&value);
    assert!(matches!(
        result,
        Err(EncodingFailure {
            condition: EncodingCondition::UnknownField { ref field },
            ..
        }) if field == "projection"
    ));
    Ok(())
}

#[test]
fn digest_entry_without_scope_is_reported_as_missing() -> Result<(), EncodingFailure> {
    let entry = JsonValue::Object(vec![("digest".into(), text(&"a".repeat(64)))]);
    let mut value = certificate(vec![]).to_value()?;
    set_field(
        &mut value,
        "digests",
        JsonValue::Object(vec![("p1".into(), entry)]),
    );
    let result = CertificateWire::from_value(&value);
    assert!(matches!(
        result,
        Err(EncodingFailure {
            condition: EncodingCondition::MissingField { field: "scope" },
            ..
        })
    ));
    Ok(())
}

#[test]
fn digest_scope_with_two_kinds_is_rejected() -> Result<(), EncodingFailure> {
    let scope = JsonValue::Object(vec![
        ("within_runtime".into(), text("rust")),
        ("cross_language".into(), text("sha256")),
    ]);
    let entry = JsonValue::Object(vec![
        ("digest".into(), text(&"a".repeat(64))),
        ("scope".into(), scope),
    ]);
    let mut value = certificate(vec![]).to_value()?;
    set_field(
        &mut value,
        "digests",
        JsonValue::Object(vec![("p1".into(), entry)]),
    );
    let result = CertificateWire::from_value(&value);
    assert!(matches!(
        result,
        Err(EncodingFailure {
            condition: EncodingCondition::UnexpectedShape { field: "scope", .. },
            ..
        })
    ));
    Ok(())
}

#[test]
fn number_in_observations_is_rejected_by_from_value() -> Result<(), EncodingFailure> {
    let mut value = certificate(vec![]).to_value()?;
    set_field(
        &mut value,
        "observations",
        JsonValue::Object(vec![("n".into(), JsonValue::Number(2.5))]),
    );
    assert_number_rejected_by_from_value(&value)
}

#[test]
fn number_in_evidence_is_rejected_by_from_value() -> Result<(), EncodingFailure> {
    let mut value = certificate(vec![]).to_value()?;
    set_field(
        &mut value,
        "evidence",
        JsonValue::Array(vec![JsonValue::Number(1.0)]),
    );
    assert_number_rejected_by_from_value(&value)
}

#[test]
fn number_in_residual_is_rejected_by_from_value() -> Result<(), EncodingFailure> {
    let mut value = certificate(vec![]).to_value()?;
    set_field(
        &mut value,
        "residuals",
        JsonValue::Array(vec![JsonValue::Object(vec![(
            "n".into(),
            JsonValue::Number(1.0),
        )])]),
    );
    assert_number_rejected_by_from_value(&value)
}

fn assert_number_rejected_by_from_value(value: &JsonValue) -> Result<(), EncodingFailure> {
    let failure = match CertificateWire::from_value(value) {
        Ok(_) => panic!("a certificate containing a number must be rejected"),
        Err(failure) => failure,
    };
    assert_eq!(failure.operation, "from_value");
    assert!(matches!(
        failure.contributing.first(),
        Some(EncodingFailure {
            condition: EncodingCondition::NumberNotCanonical { .. },
            ..
        })
    ));
    Ok(())
}

#[test]
fn number_in_coordinate_fails_canonical_bytes_and_digest() -> Result<(), EncodingFailure> {
    let mut wire = certificate(vec![]);
    wire.coordinate = JsonValue::Object(vec![("n".into(), JsonValue::Number(2.5))]);

    let failure = match wire.canonical_bytes() {
        Ok(_) => panic!("canonical_bytes must fail for a number in coordinate"),
        Err(failure) => failure,
    };
    assert_eq!(failure.operation, "canonical_bytes");
    assert!(!failure.contributing.is_empty());

    let failure = match wire.digest() {
        Ok(_) => panic!("digest must fail for a number in coordinate"),
        Err(failure) => failure,
    };
    assert_eq!(failure.operation, "digest");
    Ok(())
}
