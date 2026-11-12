use std::collections::BTreeMap;

use neco_json::JsonValue;

use crate::canonical::{canonical_bytes, normalize_value};
use crate::digest::sha256_hex;
use crate::failure::{EncodingCondition, EncodingFailure};

pub const RULE_REVISION: &str = "rule_revision";
pub const SOURCE: &str = "source";
pub const IDENTITY: &str = "identity";
pub const REVISION: &str = "revision";
pub const COORDINATE: &str = "coordinate";
pub const DIGESTS: &str = "digests";
pub const DIGEST: &str = "digest";
pub const SCOPE: &str = "scope";
pub const WITHIN_RUNTIME: &str = "within_runtime";
pub const CROSS_LANGUAGE: &str = "cross_language";
pub const RESIDUALS: &str = "residuals";
pub const OBSERVATIONS: &str = "observations";
pub const EVIDENCE: &str = "evidence";

const FROM_VALUE: &str = "from_value";
const TO_VALUE: &str = "to_value";

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DigestScope {
    WithinRuntime(String),
    CrossLanguage(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProjectionDigestWire {
    pub digest: String,
    pub scope: DigestScope,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceRefWire {
    pub identity: String,
    pub revision: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CertificateWire {
    pub rule_revision: String,
    pub source: SourceRefWire,
    pub coordinate: JsonValue,
    pub digests: BTreeMap<String, ProjectionDigestWire>,
    pub residuals: Vec<JsonValue>,
    pub observations: JsonValue,
    pub evidence: JsonValue,
}

impl CertificateWire {
    pub fn to_value(&self) -> Result<JsonValue, EncodingFailure> {
        require_normalized_residuals(&self.residuals, TO_VALUE)?;
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
        let digests = digests_from_value(field(value, DIGESTS)?)?;
        let residuals = array_field(value, RESIDUALS)?.to_vec();
        require_normalized_residuals(&residuals, FROM_VALUE)?;
        let coordinate = field(value, COORDINATE)?.clone();
        let observations = field(value, OBSERVATIONS)?.clone();
        let evidence = field(value, EVIDENCE)?.clone();
        require_canonical(&coordinate, FROM_VALUE)?;
        require_canonical(&observations, FROM_VALUE)?;
        require_canonical(&evidence, FROM_VALUE)?;
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

    pub fn canonical_bytes(&self) -> Result<Vec<u8>, EncodingFailure> {
        let value = self
            .to_value()
            .map_err(|failure| EncodingFailure::wrap("canonical_bytes", failure))?;
        canonical_bytes(&value).map_err(|failure| EncodingFailure::wrap("canonical_bytes", failure))
    }

    pub fn digest(&self) -> Result<String, EncodingFailure> {
        self.canonical_bytes()
            .and_then(|bytes| sha256_hex(&bytes))
            .map_err(|failure| EncodingFailure::wrap("digest", failure))
    }
}

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

fn digests_to_value(digests: &BTreeMap<String, ProjectionDigestWire>) -> JsonValue {
    JsonValue::Object(
        digests
            .iter()
            .map(|(name, digest)| (name.clone(), digest_to_value(digest)))
            .collect(),
    )
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
        (DIGEST.into(), JsonValue::String(digest.digest.clone())),
        (SCOPE.into(), scope),
    ])
}

fn digests_from_value(
    value: &JsonValue,
) -> Result<BTreeMap<String, ProjectionDigestWire>, EncodingFailure> {
    let fields = value
        .as_object()
        .ok_or_else(|| shape_failure(value, DIGESTS, "object"))?;
    reject_duplicate_keys(fields, DIGESTS)?;
    fields
        .iter()
        .map(|(name, digest)| Ok((name.clone(), digest_from_value(digest)?)))
        .collect()
}

fn digest_from_value(value: &JsonValue) -> Result<ProjectionDigestWire, EncodingFailure> {
    ensure_keys(value, DIGEST, &[DIGEST, SCOPE])?;
    Ok(ProjectionDigestWire {
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

fn reject_duplicate_keys(
    fields: &[(String, JsonValue)],
    path: &'static str,
) -> Result<(), EncodingFailure> {
    for (index, (key, _)) in fields.iter().enumerate() {
        if fields[..index].iter().any(|(earlier, _)| earlier == key) {
            return Err(EncodingFailure::new(
                FROM_VALUE,
                EncodingCondition::DuplicateKey {
                    path: path.to_string(),
                    key: key.clone(),
                },
            ));
        }
    }
    Ok(())
}

fn ensure_keys(
    value: &JsonValue,
    name: &'static str,
    known: &[&str],
) -> Result<(), EncodingFailure> {
    let fields = value
        .as_object()
        .ok_or_else(|| shape_failure(value, name, "object"))?;
    let unknown = fields
        .iter()
        .position(|(key, _)| !known.contains(&key.as_str()));
    reject_duplicate_keys(&fields[..unknown.unwrap_or(fields.len())], name)?;
    match unknown {
        Some(index) => Err(EncodingFailure::new(
            FROM_VALUE,
            EncodingCondition::UnknownField {
                field: fields[index].0.clone(),
            },
        )),
        None => Ok(()),
    }
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

    fn digest(fill: char) -> ProjectionDigestWire {
        ProjectionDigestWire {
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
    fn digest_map_insertion_order_does_not_change_wire_bytes() -> Result<(), EncodingFailure> {
        let mut one = BTreeMap::new();
        one.insert("p1".to_string(), digest('a'));
        one.insert("p2".to_string(), digest('b'));
        one.insert("p3".to_string(), digest('c'));
        let mut two = BTreeMap::new();
        two.insert("p3".to_string(), digest('c'));
        two.insert("p1".to_string(), digest('a'));
        two.insert("p2".to_string(), digest('b'));

        let mut first = certificate_with(one);
        let second = certificate_with(two);
        assert_eq!(first.canonical_bytes()?, second.canonical_bytes()?);
        assert_eq!(first.digest()?, second.digest()?);

        first.digests.insert("p2".to_string(), digest('d'));
        assert_ne!(first.canonical_bytes()?, second.canonical_bytes()?);
        Ok(())
    }

    #[test]
    fn scope_difference_for_same_name_changes_wire_bytes() -> Result<(), EncodingFailure> {
        let within = digest('a');
        let cross = ProjectionDigestWire {
            digest: "a".repeat(64),
            scope: DigestScope::CrossLanguage("scheme-1".into()),
        };
        let mut one = certificate_with(BTreeMap::new());
        one.digests.insert("p1".into(), within);
        let mut two = certificate_with(BTreeMap::new());
        two.digests.insert("p1".into(), cross);
        assert_ne!(one.canonical_bytes()?, two.canonical_bytes()?);
        Ok(())
    }

    fn certificate_with(digests: BTreeMap<String, ProjectionDigestWire>) -> CertificateWire {
        CertificateWire {
            rule_revision: "r".into(),
            source: SourceRefWire {
                identity: "s".into(),
                revision: "v".into(),
            },
            coordinate: JsonValue::Null,
            digests,
            residuals: vec![],
            observations: JsonValue::Null,
            evidence: JsonValue::Null,
        }
    }
}
