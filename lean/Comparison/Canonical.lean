set_option autoImplicit false

namespace NecoQuotient.Comparison.Canonical

def hexDigit (value : Nat) : Char :=
  if value < 10 then Char.ofNat (48 + value) else Char.ofNat (87 + value)

def hex4 (value : Nat) : String :=
  String.ofList [hexDigit ((value / 4096) % 16), hexDigit ((value / 256) % 16),
    hexDigit ((value / 16) % 16), hexDigit (value % 16)]

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

def stringText (text : String) : String :=
  "\"" ++ text.foldl (fun result character => result ++ escapeCharacter character) "" ++ "\""

end NecoQuotient.Comparison.Canonical
