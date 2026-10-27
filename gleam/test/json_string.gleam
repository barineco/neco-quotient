import gleam/int
import gleam/list
import gleam/string

pub fn string_literal(text: String) -> String {
  let body =
    text
    |> string.to_utf_codepoints
    |> list.map(escape_codepoint)
    |> string.concat
  "\"" <> body <> "\""
}

fn escape_codepoint(codepoint: UtfCodepoint) -> String {
  case string.utf_codepoint_to_int(codepoint) {
    0x22 -> "\\\""
    0x5C -> "\\\\"
    0x08 -> "\\b"
    0x0C -> "\\f"
    0x0A -> "\\n"
    0x0D -> "\\r"
    0x09 -> "\\t"
    code if code < 0x20 ->
      "\\u" <> string.pad_start(string.lowercase(int.to_base16(code)), 4, "0")
    _ -> string.from_utf_codepoints([codepoint])
  }
}
