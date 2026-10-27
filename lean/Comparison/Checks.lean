import Lean.Data.Json
import Comparison.Canonical
import Comparison.Sha256

set_option autoImplicit false

namespace NecoQuotient.Comparison.Checks

open NecoQuotient.Comparison

#guard Digest.toHex (Digest.sha256 ByteArray.empty) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
#guard Digest.toHex (Digest.sha256 "abc".toUTF8) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
#guard Canonical.stringText "a\x01\"\\\n\t\x7f/\r\x08\x0c" == "\"a\\u0001\\\"\\\\\\n\\t\x7f/\\r\\b\\f\""
#guard (Lean.Json.arr #[Lean.Json.mkObj [("b", Lean.Json.bool true), ("a", Lean.Json.str "x")]]).compress == "[{\"a\":\"x\",\"b\":true}]"

end NecoQuotient.Comparison.Checks
