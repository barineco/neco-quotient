#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EncodingFailure {
    pub operation: &'static str,
    pub condition: EncodingCondition,
    pub contributing: Vec<EncodingFailure>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EncodingCondition {
    NumberNotCanonical {
        path: String,
    },
    DuplicateKey {
        path: String,
        key: String,
    },
    NotCanonical {
        expected: Vec<u8>,
        actual: Vec<u8>,
    },
    Parse {
        message: String,
    },
    MissingField {
        field: &'static str,
    },
    UnknownField {
        field: String,
    },
    UnexpectedShape {
        field: &'static str,
        expected: &'static str,
        actual: String,
    },
    ResidualsNotNormalized {
        expected: Vec<u8>,
        actual: Vec<u8>,
    },
    MessageTooLong {
        length: usize,
        maximum: u64,
    },
}

impl EncodingFailure {
    pub(crate) fn new(operation: &'static str, condition: EncodingCondition) -> Self {
        Self {
            operation,
            condition,
            contributing: Vec::new(),
        }
    }

    pub(crate) fn wrap(operation: &'static str, inner: EncodingFailure) -> Self {
        Self {
            operation,
            condition: inner.condition.clone(),
            contributing: vec![inner],
        }
    }

    pub fn condition_name(&self) -> &'static str {
        match &self.condition {
            EncodingCondition::NumberNotCanonical { .. } => "number_not_canonical",
            EncodingCondition::DuplicateKey { .. } => "duplicate_key",
            EncodingCondition::NotCanonical { .. } => "not_canonical",
            EncodingCondition::Parse { .. } => "parse_failed",
            EncodingCondition::MissingField { .. } => "missing_field",
            EncodingCondition::UnknownField { .. } => "unknown_field",
            EncodingCondition::UnexpectedShape { .. } => "unexpected_shape",
            EncodingCondition::ResidualsNotNormalized { .. } => "residuals_not_normalized",
            EncodingCondition::MessageTooLong { .. } => "message_too_long",
        }
    }
}

impl std::fmt::Display for EncodingFailure {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(formatter, "{}: ", self.operation)?;
        match &self.condition {
            EncodingCondition::NumberNotCanonical { path } => {
                write!(formatter, "number at {path} is not canonical")
            }
            EncodingCondition::DuplicateKey { path, key } => {
                write!(formatter, "duplicate key {key:?} at {path}")
            }
            EncodingCondition::NotCanonical { expected, actual } => write!(
                formatter,
                "input is not canonical (expected {} bytes, actual {} bytes)",
                expected.len(),
                actual.len()
            ),
            EncodingCondition::Parse { message } => write!(formatter, "{message}"),
            EncodingCondition::MissingField { field } => {
                write!(formatter, "missing field {field:?}")
            }
            EncodingCondition::UnknownField { field } => {
                write!(formatter, "unknown field {field:?}")
            }
            EncodingCondition::UnexpectedShape {
                field,
                expected,
                actual,
            } => write!(
                formatter,
                "field {field:?} expected {expected}, actual {actual}"
            ),
            EncodingCondition::ResidualsNotNormalized { expected, actual } => write!(
                formatter,
                "residuals are not in normal form (expected {} bytes, actual {} bytes)",
                expected.len(),
                actual.len()
            ),
            EncodingCondition::MessageTooLong { length, maximum } => write!(
                formatter,
                "SHA-256 message of {length} bytes exceeds {maximum} bytes"
            ),
        }
    }
}

impl std::error::Error for EncodingFailure {}
