use neco_json::JsonValue;

use crate::canonical::{canonical_bytes, normalize_value};
use crate::digest::sha256_hex;
use crate::failure::{EncodingCondition, EncodingFailure};

/// Key names used by the certificate wire format.
pub const RULE_REVISION: &str = "rule_revision";
pub const SOURCE: &str = "source";
pub const IDENTITY: &str = "identity";
pub const REVISION: &str = "revision";
pub const COORDINATE: &str = "coordinate";
pub const DIGESTS: &str = "digests";
pub const PROJECTION: &str = "projection";
pub const DIGEST: &str = "digest";
pub const SCOPE: &str = "scope";
pub const WITHIN_RUNTIME: &str = "within_runtime";
pub const CROSS_LANGUAGE: &str = "cross_language";
pub const RESIDUALS: &str = "residuals";
pub const OBSERVATIONS: &str = "observations";
pub const EVIDENCE: &str = "evidence";

const FROM_VALUE: &str = "from_value";
const TO_VALUE: &str = "to_value";

/// Scope in which a projection digest is meaningful.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DigestScope {
    /// The digest is comparable only within the named runtime.
    WithinRuntime(String),
    /// The digest is comparable across languages under the named scheme.
    CrossLanguage(String),
}

/// A digest of one projection together with its scope.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProjectionDigestWire {
    pub projection: String,
    pub digest: String,
    pub scope: DigestScope,
}

/// Identity and revision of the source a certificate refers to.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceRefWire {
    pub identity: String,
    pub revision: String,
}

/// Wire form of a quotient certificate.
#[derive(Debug, Clone, PartialEq)]
pub struct CertificateWire {
    pub rule_revision: String,
    pub source: SourceRefWire,
    pub coordinate: JsonValue,
    pub digests: Vec<ProjectionDigestWire>,
    pub residuals: Vec<JsonValue>,
    pub observations: JsonValue,
    pub evidence: JsonValue,
}

impl CertificateWire {
    /// Converts the certificate into a JSON value with the wire key names.
    /// The residuals and the digests must already be in normal form.
    pub fn to_value(&self) -> Result<JsonValue, EncodingFailure> {
        require_normalized_residuals(&self.residuals, TO_VALUE)?;
        require_normalized_digests(&self.digests, TO_VALUE)?;
        Ok(JsonValue::Object(vec![
            (
                RULE_REVISION.into(),
                JsonValue::String(self.rule_revision.clone()),
            ),
            (SOURCE.into(), source_to_value(&self.source)),
            (COORDINATE.into(), self.coordinate.clone()),
            (DIGESTS.into(), digests_to_value(&self.digests)),
            (RESIDUALS.into(), JsonValue::Array(self.residuals.clone())),
            (OBSERVATIONS.into(), self.observations.clone()),
            (EVIDENCE.into(), self.evidence.clone()),
        ]))
    }

    /// Reads a certificate from a JSON value. Rejects unknown and duplicate keys,
    /// missing or mistyped fields, values that have no canonical bytes,
    /// and residuals or digests that are not in normal form.
    pub fn from_value(value: &JsonValue) -> Result<Self, EncodingFailure> {
        ensure_keys(
            value,
            "certificate",
            &[
                RULE_REVISION,
                SOURCE,
                COORDINATE,
                DIGESTS,
                RESIDUALS,
                OBSERVATIONS,
                EVIDENCE,
            ],
        )?;
        let digests = array_field(value, DIGESTS)?
            .iter()
            .map(digest_from_value)
            .collect::<Result<Vec<_>, _>>()?;
        let residuals = array_field(value, RESIDUALS)?.to_vec();
        require_normalized_residuals(&residuals, FROM_VALUE)?;
        require_normalized_digests(&digests, FROM_VALUE)?;
        let coordinate = field(value, COORDINATE)?.clone();
        let observations = field(value, OBSERVATIONS)?.clone();
        let evidence = field(value, EVIDENCE)?.clone();
        require_canonical(&coordinate, FROM_VALUE)?;
        require_canonical(&observations, FROM_VALUE)?;
        require_canonical(&evidence, FROM_VALUE)?;
        for residual in &residuals {
            require_canonical(residual, FROM_VALUE)?;
        }
        Ok(Self {
            rule_revision: string_field(value, RULE_REVISION)?,
            source: source_from_value(field(value, SOURCE)?)?,
            coordinate,
            digests,
            residuals,
            observations,
            evidence,
        })
    }

    /// Returns the canonical bytes of the wire form.
    pub fn canonical_bytes(&self) -> Result<Vec<u8>, EncodingFailure> {
        let value = self
            .to_value()
            .map_err(|failure| EncodingFailure::wrap("canonical_bytes", failure))?;
        canonical_bytes(&value).map_err(|failure| EncodingFailure::wrap("canonical_bytes", failure))
    }

    /// Returns the lowercase hexadecimal SHA-256 digest of the canonical bytes.
    pub fn digest(&self) -> Result<String, EncodingFailure> {
        self.canonical_bytes()
            .map(|bytes| sha256_hex(&bytes))
            .map_err(|failure| EncodingFailure::wrap("digest", failure))
    }
}

/// Sorts residuals by their canonical bytes and removes entries with identical bytes.
/// Each returned element is in normalized form, so the result does not depend on input order.
pub fn normalize_residuals(residuals: Vec<JsonValue>) -> Result<Vec<JsonValue>, EncodingFailure> {
    let mut keyed = residuals
        .iter()
        .map(|residual| {
            let normalized = normalize_value(residual)
                .map_err(|condition| EncodingFailure::new("normalize_residuals", condition))?;
            let bytes = canonical_bytes(&normalized)
                .map_err(|failure| EncodingFailure::wrap("normalize_residuals", failure))?;
            Ok((bytes, normalized))
        })
        .collect::<Result<Vec<_>, EncodingFailure>>()?;
    keyed.sort_by(|left, right| left.0.cmp(&right.0));
    keyed.dedup_by(|current, kept| current.0 == kept.0);
    Ok(keyed.into_iter().map(|(_, value)| value).collect())
}

/// Sorts digests by the bytes of their projection and removes exact duplicates.
/// The normal form lists each projection once, in ascending byte order.
/// A projection that appears with a different digest or scope is rejected.
pub fn normalize_digests(
    digests: Vec<ProjectionDigestWire>,
) -> Result<Vec<ProjectionDigestWire>, EncodingFailure> {
    let mut sorted = digests;
    sorted.sort_by(|left, right| left.projection.as_bytes().cmp(right.projection.as_bytes()));
    let mut normalized: Vec<ProjectionDigestWire> = Vec::with_capacity(sorted.len());
    for digest in sorted {
        if let Some(kept) = normalized.last() {
            if kept.projection == digest.projection {
                if *kept != digest {
                    return Err(EncodingFailure::new(
                        "normalize_digests",
                        EncodingCondition::DuplicateProjection {
                            projection: digest.projection,
                        },
                    ));
                }
                continue;
            }
        }
        normalized.push(digest);
    }
    Ok(normalized)
}

fn require_normalized_residuals(
    residuals: &[JsonValue],
    operation: &'static str,
) -> Result<(), EncodingFailure> {
    let normalized = normalize_residuals(residuals.to_vec())
        .map_err(|failure| EncodingFailure::wrap(operation, failure))?;
    if normalized.as_slice() == residuals {
        return Ok(());
    }
    let expected = canonical_bytes(&JsonValue::Array(normalized))
        .map_err(|failure| EncodingFailure::wrap(operation, failure))?;
    let actual = canonical_bytes(&JsonValue::Array(residuals.to_vec()))
        .map_err(|failure| EncodingFailure::wrap(operation, failure))?;
    Err(EncodingFailure::new(
        operation,
        EncodingCondition::ResidualsNotNormalized { expected, actual },
    ))
}

fn require_normalized_digests(
    digests: &[ProjectionDigestWire],
    operation: &'static str,
) -> Result<(), EncodingFailure> {
    let normalized = normalize_digests(digests.to_vec())
        .map_err(|failure| EncodingFailure::wrap(operation, failure))?;
    if normalized.as_slice() == digests {
        return Ok(());
    }
    let expected = canonical_bytes(&digests_to_value(&normalized))
        .map_err(|failure| EncodingFailure::wrap(operation, failure))?;
    let actual = canonical_bytes(&digests_to_value(digests))
        .map_err(|failure| EncodingFailure::wrap(operation, failure))?;
    Err(EncodingFailure::new(
        operation,
        EncodingCondition::DigestsNotNormalized { expected, actual },
    ))
}

fn require_canonical(value: &JsonValue, operation: &'static str) -> Result<(), EncodingFailure> {
    canonical_bytes(value)
        .map(|_| ())
        .map_err(|failure| EncodingFailure::wrap(operation, failure))
}

fn source_to_value(source: &SourceRefWire) -> JsonValue {
    JsonValue::Object(vec![
        (IDENTITY.into(), JsonValue::String(source.identity.clone())),
        (REVISION.into(), JsonValue::String(source.revision.clone())),
    ])
}

fn source_from_value(value: &JsonValue) -> Result<SourceRefWire, EncodingFailure> {
    ensure_keys(value, SOURCE, &[IDENTITY, REVISION])?;
    Ok(SourceRefWire {
        identity: string_field(value, IDENTITY)?,
        revision: string_field(value, REVISION)?,
    })
}

fn digests_to_value(digests: &[ProjectionDigestWire]) -> JsonValue {
    JsonValue::Array(digests.iter().map(digest_to_value).collect())
}

fn digest_to_value(digest: &ProjectionDigestWire) -> JsonValue {
    let scope = match &digest.scope {
        DigestScope::WithinRuntime(name) => JsonValue::Object(vec![(
            WITHIN_RUNTIME.into(),
            JsonValue::String(name.clone()),
        )]),
        DigestScope::CrossLanguage(name) => JsonValue::Object(vec![(
            CROSS_LANGUAGE.into(),
            JsonValue::String(name.clone()),
        )]),
    };
    JsonValue::Object(vec![
        (
            PROJECTION.into(),
            JsonValue::String(digest.projection.clone()),
        ),
        (DIGEST.into(), JsonValue::String(digest.digest.clone())),
        (SCOPE.into(), scope),
    ])
}

fn digest_from_value(value: &JsonValue) -> Result<ProjectionDigestWire, EncodingFailure> {
    ensure_keys(value, DIGESTS, &[PROJECTION, DIGEST, SCOPE])?;
    Ok(ProjectionDigestWire {
        projection: string_field(value, PROJECTION)?,
        digest: string_field(value, DIGEST)?,
        scope: scope_from_value(field(value, SCOPE)?)?,
    })
}

fn scope_from_value(value: &JsonValue) -> Result<DigestScope, EncodingFailure> {
    ensure_keys(value, SCOPE, &[WITHIN_RUNTIME, CROSS_LANGUAGE])?;
    let fields = value
        .as_object()
        .ok_or_else(|| shape_failure(value, SCOPE, "object"))?;
    match fields {
        [(key, JsonValue::String(name))] if key == WITHIN_RUNTIME => {
            Ok(DigestScope::WithinRuntime(name.clone()))
        }
        [(key, JsonValue::String(name))] if key == CROSS_LANGUAGE => {
            Ok(DigestScope::CrossLanguage(name.clone()))
        }
        _ => Err(shape_failure(
            value,
            SCOPE,
            "object with one of within_runtime or cross_language",
        )),
    }
}

fn kind_name(value: &JsonValue) -> &'static str {
    match value {
        JsonValue::Null => "null",
        JsonValue::Bool(_) => "bool",
        JsonValue::Number(_) => "number",
        JsonValue::String(_) => "string",
        JsonValue::Array(_) => "array",
        JsonValue::Object(_) => "object",
    }
}

fn shape_failure(
    value: &JsonValue,
    field: &'static str,
    expected: &'static str,
) -> EncodingFailure {
    EncodingFailure::new(
        FROM_VALUE,
        EncodingCondition::UnexpectedShape {
            field,
            expected,
            actual: kind_name(value).to_string(),
        },
    )
}

fn ensure_keys(
    value: &JsonValue,
    name: &'static str,
    known: &[&str],
) -> Result<(), EncodingFailure> {
    let fields = value
        .as_object()
        .ok_or_else(|| shape_failure(value, name, "object"))?;
    for (index, (key, _)) in fields.iter().enumerate() {
        if fields[..index].iter().any(|(earlier, _)| earlier == key) {
            return Err(EncodingFailure::new(
                FROM_VALUE,
                EncodingCondition::DuplicateKey {
                    path: name.to_string(),
                    key: key.clone(),
                },
            ));
        }
        if !known.contains(&key.as_str()) {
            return Err(EncodingFailure::new(
                FROM_VALUE,
                EncodingCondition::UnknownField { field: key.clone() },
            ));
        }
    }
    Ok(())
}

fn field<'a>(object: &'a JsonValue, name: &'static str) -> Result<&'a JsonValue, EncodingFailure> {
    object.get(name).ok_or_else(|| {
        EncodingFailure::new(FROM_VALUE, EncodingCondition::MissingField { field: name })
    })
}

fn string_field(object: &JsonValue, name: &'static str) -> Result<String, EncodingFailure> {
    let value = field(object, name)?;
    value
        .as_str()
        .map(str::to_string)
        .ok_or_else(|| shape_failure(value, name, "string"))
}

fn array_field<'a>(
    object: &'a JsonValue,
    name: &'static str,
) -> Result<&'a [JsonValue], EncodingFailure> {
    let value = field(object, name)?;
    value
        .as_array()
        .ok_or_else(|| shape_failure(value, name, "array"))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn text(value: &str) -> JsonValue {
        JsonValue::String(value.into())
    }

    fn digest(projection: &str, fill: char) -> ProjectionDigestWire {
        ProjectionDigestWire {
            projection: projection.into(),
            digest: fill.to_string().repeat(64),
            scope: DigestScope::WithinRuntime("rust".into()),
        }
    }

    #[test]
    fn normalize_residuals_is_idempotent() -> Result<(), EncodingFailure> {
        let input = vec![
            JsonValue::Object(vec![("y".into(), text("2")), ("x".into(), text("1"))]),
            JsonValue::Array(vec![text("z")]),
            JsonValue::Object(vec![("x".into(), text("1")), ("y".into(), text("2"))]),
        ];
        let once = normalize_residuals(input)?;
        let twice = normalize_residuals(once.clone())?;
        assert_eq!(once, twice);
        Ok(())
    }

    #[test]
    fn normalize_residuals_is_order_independent() -> Result<(), EncodingFailure> {
        let first = JsonValue::Object(vec![("x".into(), text("1")), ("y".into(), text("2"))]);
        let first_permuted =
            JsonValue::Object(vec![("y".into(), text("2")), ("x".into(), text("1"))]);
        let second = JsonValue::Object(vec![("k".into(), text("v"))]);

        let one = normalize_residuals(vec![first.clone(), second.clone(), first_permuted.clone()])?;
        let two = normalize_residuals(vec![second, first_permuted, first])?;

        assert_eq!(one, two);
        Ok(())
    }

    #[test]
    fn normalize_residuals_removes_duplicates() -> Result<(), EncodingFailure> {
        let first = JsonValue::Object(vec![("x".into(), text("1")), ("y".into(), text("2"))]);
        let first_permuted =
            JsonValue::Object(vec![("y".into(), text("2")), ("x".into(), text("1"))]);
        let second = JsonValue::Array(vec![text("z")]);

        let normalized = normalize_residuals(vec![first, second, first_permuted])?;
        assert_eq!(normalized.len(), 2);
        Ok(())
    }

    #[test]
    fn normalize_digests_is_idempotent() -> Result<(), EncodingFailure> {
        let input = vec![digest("p2", 'b'), digest("p1", 'a'), digest("p2", 'b')];
        let once = normalize_digests(input)?;
        let twice = normalize_digests(once.clone())?;
        assert_eq!(once, twice);
        assert_eq!(once.len(), 2);
        Ok(())
    }

    #[test]
    fn normalize_digests_is_order_independent() -> Result<(), EncodingFailure> {
        let one = normalize_digests(vec![
            digest("p1", 'a'),
            digest("p3", 'c'),
            digest("p2", 'b'),
        ])?;
        let two = normalize_digests(vec![
            digest("p2", 'b'),
            digest("p3", 'c'),
            digest("p1", 'a'),
        ])?;
        assert_eq!(one, two);
        Ok(())
    }

    #[test]
    fn conflicting_digest_for_same_projection_is_rejected() -> Result<(), EncodingFailure> {
        let result = normalize_digests(vec![digest("p1", 'a'), digest("p1", 'b')]);
        assert!(matches!(
            result,
            Err(EncodingFailure {
                operation: "normalize_digests",
                condition: EncodingCondition::DuplicateProjection { ref projection },
                ..
            }) if projection == "p1"
        ));
        Ok(())
    }

    #[test]
    fn scope_only_difference_for_same_projection_is_rejected() -> Result<(), EncodingFailure> {
        let within = digest("p1", 'a');
        let cross = ProjectionDigestWire {
            projection: "p1".into(),
            digest: "a".repeat(64),
            scope: DigestScope::CrossLanguage("scheme-1".into()),
        };
        let result = normalize_digests(vec![within, cross]);
        assert!(matches!(
            result,
            Err(EncodingFailure {
                operation: "normalize_digests",
                condition: EncodingCondition::DuplicateProjection { ref projection },
                ..
            }) if projection == "p1"
        ));
        Ok(())
    }
}
