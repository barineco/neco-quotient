use neco_quotient_encoding::{
    decode_canonical, CertificateWire, DigestScope, EncodingCondition, EncodingFailure, JsonValue,
    ProjectionDigestWire, SourceRefWire,
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
        digests: vec![],
        residuals,
        observations: JsonValue::Null,
        evidence: JsonValue::Null,
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
        ("digests".into(), JsonValue::Array(vec![])),
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

fn set_field(value: &mut JsonValue, key: &str, replacement: JsonValue) {
    if let JsonValue::Object(fields) = value {
        for (name, child) in fields.iter_mut() {
            if name == key {
                *child = replacement.clone();
            }
        }
    }
}

fn digest(projection: &str, fill: char) -> ProjectionDigestWire {
    ProjectionDigestWire {
        projection: projection.into(),
        digest: fill.to_string().repeat(64),
        scope: DigestScope::WithinRuntime("rust".into()),
    }
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
fn non_normal_digests_are_rejected_by_to_value() -> Result<(), EncodingFailure> {
    let mut wire = certificate(vec![]);
    wire.digests = vec![digest("p2", 'b'), digest("p1", 'a')];
    let result = wire.to_value();
    assert_eq!(
        result.err().map(|failure| failure.condition_name()),
        Some("digests_not_normalized")
    );
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
