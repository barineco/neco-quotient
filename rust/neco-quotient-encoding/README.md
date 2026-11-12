# neco-quotient-encoding

証明書を表す JSON 値を正規のバイト列へ変換し、同じ値から同じ SHA-256 ハッシュ値を得るための crate です。通信形式の復号では、欄の型と正規形を検査します。

## 公開 API

| 名前 | 役割 |
|---|---|
| `canonical_bytes` | JSON 値を正規のバイト列へ変換する |
| `decode_canonical` | 正規のバイト列を JSON 値へ復号する |
| `sha256_hex` | バイト列の SHA-256 ハッシュ値を小文字の十六進で `Result` として返し、入力が 2^61−1 バイトを超えると失敗する |
| `CertificateWire` | 証明書の通信形式を表す |
| `ProjectionDigestWire` | 射影ダイジェストの通信形式を表す |
| `SourceRefWire` | 入力参照の通信形式を表す |
| `normalize_residuals` | 残余を通信形式の順序へ正規化する |
| `EncodingFailure` | 符号化を終了させた条件、操作、寄与した下位の失敗を返す |

## JSON 値の符号化

```rust
use neco_quotient_encoding::{canonical_bytes, decode_canonical, sha256_hex, JsonValue};

let value = JsonValue::Object(vec![
    ("identity".into(), JsonValue::String("source-a".into())),
]);
let bytes = canonical_bytes(&value)?;
let decoded = decode_canonical(&bytes)?;

assert_eq!(decoded, value);
assert_eq!(sha256_hex(&bytes)?.len(), 64);
# Ok::<(), neco_quotient_encoding::EncodingFailure>(())
```

符号化の規則と証明書の形式は [docs/certificate.md](../../docs/certificate.md) を参照してください。

## ライセンス

MIT
