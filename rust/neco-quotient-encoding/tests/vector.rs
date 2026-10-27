use neco_quotient_encoding::{canonical_bytes, EncodingFailure, JsonValue};

#[test]
fn escape_table_matches_canonical_output() -> Result<(), EncodingFailure> {
    let table: [(&str, &str); 14] = [
        ("\"", "\\\""),
        ("\\", "\\\\"),
        ("\u{8}", "\\b"),
        ("\u{c}", "\\f"),
        ("\n", "\\n"),
        ("\r", "\\r"),
        ("\t", "\\t"),
        ("\u{0}", "\\u0000"),
        ("\u{1f}", "\\u001f"),
        ("/", "/"),
        ("\u{7f}", "\u{7f}"),
        ("\u{e9}", "\u{e9}"),
        ("\u{65e5}", "\u{65e5}"),
        ("\u{1f600}", "\u{1f600}"),
    ];
    for (input, output) in table {
        let expected = format!("\"{output}\"").into_bytes();
        assert_eq!(
            canonical_bytes(&JsonValue::String(input.into()))?,
            expected,
            "input {input:?}"
        );
    }
    Ok(())
}

#[test]
fn control_character_is_written_as_lowercase_unicode_escape() -> Result<(), EncodingFailure> {
    let value = JsonValue::String("a\u{1f}b".into());
    assert_eq!(canonical_bytes(&value)?, br#""a\u001fb""#);
    Ok(())
}
