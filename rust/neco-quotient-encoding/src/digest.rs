use neco_sha2::{Sha256, MAX_MESSAGE_BYTES};

use crate::failure::{EncodingCondition, EncodingFailure};

pub fn sha256_hex(bytes: &[u8]) -> Result<String, EncodingFailure> {
    Sha256::digest(bytes)
        .map(|digest| digest.iter().map(|byte| format!("{byte:02x}")).collect())
        .map_err(|_| {
            EncodingFailure::new(
                "sha256_hex",
                EncodingCondition::MessageTooLong {
                    length: bytes.len(),
                    maximum: MAX_MESSAGE_BYTES,
                },
            )
        })
}

#[cfg(test)]
mod tests {
    use super::sha256_hex;
    use crate::failure::EncodingFailure;

    #[test]
    fn sha256_matches_fips_180_4_vectors() -> Result<(), EncodingFailure> {
        assert_eq!(
            sha256_hex(b"")?,
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
        assert_eq!(
            sha256_hex(b"abc")?,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        assert_eq!(
            sha256_hex(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")?,
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        );
        Ok(())
    }
}
