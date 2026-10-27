use neco_quotient_encoding::{canonical_bytes, EncodingFailure, JsonValue};

fn text(value: &str) -> JsonValue {
    JsonValue::String(value.into())
}

#[test]
fn object_key_insertion_order_does_not_change_canonical_bytes() -> Result<(), EncodingFailure> {
    let forward = JsonValue::Object(vec![
        ("a".into(), text("1")),
        ("b".into(), text("2")),
        ("c".into(), JsonValue::Array(vec![text("x"), text("y")])),
    ]);
    let reversed = JsonValue::Object(vec![
        ("c".into(), JsonValue::Array(vec![text("x"), text("y")])),
        ("b".into(), text("2")),
        ("a".into(), text("1")),
    ]);

    assert_eq!(canonical_bytes(&forward)?, canonical_bytes(&reversed)?);
    Ok(())
}

#[test]
fn nested_object_key_insertion_order_does_not_change_canonical_bytes() -> Result<(), EncodingFailure>
{
    let forward = JsonValue::Object(vec![(
        "outer".into(),
        JsonValue::Object(vec![
            ("p".into(), text("1")),
            (
                "q".into(),
                JsonValue::Object(vec![("m".into(), text("3")), ("n".into(), text("4"))]),
            ),
        ]),
    )]);
    let reversed = JsonValue::Object(vec![(
        "outer".into(),
        JsonValue::Object(vec![
            (
                "q".into(),
                JsonValue::Object(vec![("n".into(), text("4")), ("m".into(), text("3"))]),
            ),
            ("p".into(), text("1")),
        ]),
    )]);
    let changed = JsonValue::Object(vec![(
        "outer".into(),
        JsonValue::Object(vec![
            ("p".into(), text("1")),
            (
                "q".into(),
                JsonValue::Object(vec![("m".into(), text("3")), ("n".into(), text("5"))]),
            ),
        ]),
    )]);

    let encoded = canonical_bytes(&forward)?;
    assert_eq!(encoded, canonical_bytes(&reversed)?);
    assert_ne!(encoded, canonical_bytes(&changed)?);
    Ok(())
}

fn position_of(haystack: &[u8], needle: &str) -> Option<usize> {
    haystack
        .windows(needle.len())
        .position(|window| window == needle.as_bytes())
}

#[test]
fn non_ascii_keys_are_ordered_by_utf8_bytes() -> Result<(), EncodingFailure> {
    let forward = JsonValue::Object(vec![
        ("\u{3042}".into(), text("1")),
        ("a".into(), text("2")),
        ("\u{e9}".into(), text("3")),
        ("Z".into(), text("4")),
        ("\u{1f600}".into(), text("5")),
        ("\u{ff61}".into(), text("6")),
    ]);
    let reversed = JsonValue::Object(vec![
        ("\u{ff61}".into(), text("6")),
        ("Z".into(), text("4")),
        ("\u{e9}".into(), text("3")),
        ("\u{1f600}".into(), text("5")),
        ("a".into(), text("2")),
        ("\u{3042}".into(), text("1")),
    ]);

    let encoded = canonical_bytes(&forward)?;
    assert_eq!(encoded, canonical_bytes(&reversed)?);

    let positions: Vec<usize> = [
        "\"Z\":",
        "\"a\":",
        "\"\u{e9}\":",
        "\"\u{3042}\":",
        "\"\u{ff61}\":",
        "\"\u{1f600}\":",
    ]
    .iter()
    .filter_map(|needle| position_of(&encoded, needle))
    .collect();
    assert_eq!(positions.len(), 6);
    assert!(positions.windows(2).all(|pair| pair[0] < pair[1]));

    let halfwidth = position_of(&encoded, "\"\u{ff61}\":");
    let emoji = position_of(&encoded, "\"\u{1f600}\":");
    assert!(halfwidth < emoji);
    Ok(())
}
