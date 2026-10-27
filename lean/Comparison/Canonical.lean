set_option autoImplicit false

namespace NecoQuotient.Comparison.Canonical

/-- 十六進の一桁 -/
def hexDigit (value : Nat) : Char :=
  if value < 10 then Char.ofNat (48 + value) else Char.ofNat (87 + value)

/-- 小文字の四桁の十六進 -/
def hex4 (value : Nat) : String :=
  String.ofList [hexDigit ((value / 4096) % 16), hexDigit ((value / 256) % 16),
    hexDigit ((value / 16) % 16), hexDigit (value % 16)]

/-- 文字列の一文字の正規の符号化: 引用符と逆斜線を escape し、backspace、formfeed、newline、return、tab を短い escape にし、他の U+0020 未満を小文字の四桁の十六進にする。その他の文字は UTF-8 のまま書く -/
def escapeCharacter (character : Char) : String :=
  if character == '"' then "\\\""
  else if character == '\\' then "\\\\"
  else if character.toNat == 8 then "\\b"
  else if character.toNat == 12 then "\\f"
  else if character.toNat == 10 then "\\n"
  else if character.toNat == 13 then "\\r"
  else if character.toNat == 9 then "\\t"
  else if character.toNat < 32 then "\\u" ++ hex4 character.toNat
  else String.singleton character

/-- 文字列の正規の JSON 表記 -/
def stringText (text : String) : String :=
  "\"" ++ text.foldl (fun result character => result ++ escapeCharacter character) "" ++ "\""

end NecoQuotient.Comparison.Canonical
