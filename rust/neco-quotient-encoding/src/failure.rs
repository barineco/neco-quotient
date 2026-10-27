/// Failure returned by canonical encoding, canonical decoding, digesting and certificate conversion.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EncodingFailure {
    /// Name of the operation that reports this failure.
    pub operation: &'static str,
    /// Condition that this failure reports.
    pub condition: EncodingCondition,
    /// Failures of the inner operations that produced this failure.
    pub contributing: Vec<EncodingFailure>,
}

/// Condition reported by an `EncodingFailure`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EncodingCondition {
    /// A `Number` was found at `path`; canonical form forbids numbers.
    /// The textual representation of numbers is the caller's convention.
    NumberNotCanonical { path: String },
    /// An object at `path` contains the key `key` more than once.
    DuplicateKey { path: String, key: String },
    /// The input bytes differ from the canonical re-encoding of the parsed value.
    NotCanonical { expected: Vec<u8>, actual: Vec<u8> },
    /// The input bytes are not valid JSON, or the JSON parser rejected them.
    Parse { message: String },
    /// A required field is absent from an object.
    MissingField { field: &'static str },
    /// An object contains a key that the wire format does not define.
    UnknownField { field: String },
    /// A field has a value of the wrong JSON type or shape.
    /// `actual` is the kind of the observed value, such as `"number"`.
    UnexpectedShape {
        field: &'static str,
        expected: &'static str,
        actual: String,
    },
    /// The residuals are not in normal form; `expected` and `actual` are their canonical bytes.
    ResidualsNotNormalized { expected: Vec<u8>, actual: Vec<u8> },
    /// The digests are not in normal form; `expected` and `actual` are their canonical bytes.
    DigestsNotNormalized { expected: Vec<u8>, actual: Vec<u8> },
    /// The same projection appears more than once with a different digest or scope.
    DuplicateProjection { projection: String },
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

    /// Returns the snake_case name of the condition that this failure reports.
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
            EncodingCondition::DigestsNotNormalized { .. } => "digests_not_normalized",
            EncodingCondition::DuplicateProjection { .. } => "duplicate_projection",
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
            EncodingCondition::DigestsNotNormalized { expected, actual } => write!(
                formatter,
                "digests are not in normal form (expected {} bytes, actual {} bytes)",
                expected.len(),
                actual.len()
            ),
            EncodingCondition::DuplicateProjection { projection } => {
                write!(
                    formatter,
                    "projection {projection:?} has a conflicting digest or scope"
                )
            }
        }
    }
}

impl std::error::Error for EncodingFailure {}
