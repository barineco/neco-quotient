use neco_json::JsonValue;

use crate::failure::{EncodingCondition, EncodingFailure};

/// Returns the canonical bytes of the value: sorted object keys, no whitespace.
/// Numbers and duplicate keys are rejected.
pub fn canonical_bytes(value: &JsonValue) -> Result<Vec<u8>, EncodingFailure> {
    let mut out = Vec::new();
    write_canonical(value, "$", &mut out)
        .map_err(|condition| EncodingFailure::new("canonical_bytes", condition))?;
    Ok(out)
}

/// Parses the bytes and returns the value when the bytes are already canonical.
/// Returns `EncodingCondition::NotCanonical` when canonical re-encoding differs from the input bytes.
pub fn decode_canonical(bytes: &[u8]) -> Result<JsonValue, EncodingFailure> {
    let parsed = neco_json::parse(bytes).map_err(|error| {
        EncodingFailure::new(
            "decode_canonical",
            EncodingCondition::Parse {
                message: error.to_string(),
            },
        )
    })?;
    let expected = canonical_bytes(&parsed)
        .map_err(|failure| EncodingFailure::wrap("decode_canonical", failure))?;
    if expected != bytes {
        return Err(EncodingFailure::new(
            "decode_canonical",
            EncodingCondition::NotCanonical {
                expected,
                actual: bytes.to_vec(),
            },
        ));
    }
    Ok(parsed)
}

pub(crate) fn normalize_value(value: &JsonValue) -> Result<JsonValue, EncodingCondition> {
    normalize_at(value, "$")
}

fn normalize_at(value: &JsonValue, path: &str) -> Result<JsonValue, EncodingCondition> {
    match value {
        JsonValue::Null => Ok(JsonValue::Null),
        JsonValue::Bool(flag) => Ok(JsonValue::Bool(*flag)),
        JsonValue::String(text) => Ok(JsonValue::String(text.clone())),
        JsonValue::Number(_) => Err(EncodingCondition::NumberNotCanonical {
            path: path.to_string(),
        }),
        JsonValue::Array(items) => items
            .iter()
            .enumerate()
            .map(|(index, item)| normalize_at(item, &format!("{path}[{index}]")))
            .collect::<Result<Vec<_>, _>>()
            .map(JsonValue::Array),
        JsonValue::Object(fields) => sorted_fields(fields, path)?
            .into_iter()
            .map(|(key, child)| {
                normalize_at(child, &format!("{path}.{key}"))
                    .map(|normalized| (key.clone(), normalized))
            })
            .collect::<Result<Vec<_>, _>>()
            .map(JsonValue::Object),
    }
}

fn write_canonical(
    value: &JsonValue,
    path: &str,
    out: &mut Vec<u8>,
) -> Result<(), EncodingCondition> {
    match value {
        JsonValue::Null => out.extend_from_slice(b"null"),
        JsonValue::Bool(true) => out.extend_from_slice(b"true"),
        JsonValue::Bool(false) => out.extend_from_slice(b"false"),
        JsonValue::Number(_) => {
            return Err(EncodingCondition::NumberNotCanonical {
                path: path.to_string(),
            })
        }
        JsonValue::String(text) => write_string(text, out),
        JsonValue::Array(items) => {
            out.push(b'[');
            for (index, item) in items.iter().enumerate() {
                if index > 0 {
                    out.push(b',');
                }
                write_canonical(item, &format!("{path}[{index}]"), out)?;
            }
            out.push(b']');
        }
        JsonValue::Object(fields) => {
            out.push(b'{');
            for (index, (key, child)) in sorted_fields(fields, path)?.into_iter().enumerate() {
                if index > 0 {
                    out.push(b',');
                }
                write_string(key, out);
                out.push(b':');
                write_canonical(child, &format!("{path}.{key}"), out)?;
            }
            out.push(b'}');
        }
    }
    Ok(())
}

fn sorted_fields<'a>(
    fields: &'a [(String, JsonValue)],
    path: &str,
) -> Result<Vec<&'a (String, JsonValue)>, EncodingCondition> {
    let mut sorted: Vec<&(String, JsonValue)> = fields.iter().collect();
    sorted.sort_by(|left, right| left.0.cmp(&right.0));
    for pair in sorted.windows(2) {
        if pair[0].0 == pair[1].0 {
            return Err(EncodingCondition::DuplicateKey {
                path: path.to_string(),
                key: pair[0].0.clone(),
            });
        }
    }
    Ok(sorted)
}

fn write_string(text: &str, out: &mut Vec<u8>) {
    out.push(b'"');
    for character in text.chars() {
        match character {
            '"' => out.extend_from_slice(b"\\\""),
            '\\' => out.extend_from_slice(b"\\\\"),
            '\u{8}' => out.extend_from_slice(b"\\b"),
            '\u{c}' => out.extend_from_slice(b"\\f"),
            '\n' => out.extend_from_slice(b"\\n"),
            '\r' => out.extend_from_slice(b"\\r"),
            '\t' => out.extend_from_slice(b"\\t"),
            control if (control as u32) < 0x20 => {
                out.extend_from_slice(format!("\\u{:04x}", control as u32).as_bytes())
            }
            other => {
                let mut buffer = [0u8; 4];
                out.extend_from_slice(other.encode_utf8(&mut buffer).as_bytes());
            }
        }
    }
    out.push(b'"');
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn number_is_rejected() -> Result<(), EncodingFailure> {
        let failure = canonical_bytes(&JsonValue::Number(1.0));
        assert_eq!(
            failure.err().map(|failure| failure.condition_name()),
            Some("number_not_canonical")
        );
        let nested = JsonValue::Object(vec![("n".into(), JsonValue::Number(2.5))]);
        let failure = canonical_bytes(&nested);
        assert_eq!(
            failure.err().map(|failure| failure.condition_name()),
            Some("number_not_canonical")
        );
        Ok(())
    }

    #[test]
    fn duplicate_key_is_rejected() {
        let object = JsonValue::Object(vec![
            ("a".into(), JsonValue::String("x".into())),
            ("a".into(), JsonValue::String("y".into())),
        ]);
        let result = canonical_bytes(&object);
        assert!(matches!(
            result,
            Err(EncodingFailure {
                condition: EncodingCondition::DuplicateKey { ref key, .. },
                ..
            }) if key == "a"
        ));
    }
}
