use neco_quotient_certificate::{RefinementOutcome, ResidualSet};
use neco_quotient_encoding::{canonical_bytes, decode_canonical, JsonValue};

type Outcome = RefinementOutcome<String, String, String>;

const CASES: &[u8] = include_bytes!("../../../comparison/refinement-outcome/cases.json");
const LEAN_OUTCOMES: &[u8] =
    include_bytes!("../../../comparison/refinement-outcome/lean-outcomes.json");

fn field<'a>(object: &'a JsonValue, key: &str) -> &'a JsonValue {
    object
        .get(key)
        .unwrap_or_else(|| panic!("missing field {key}"))
}

fn text(value: &JsonValue) -> String {
    value.as_str().expect("the value is a string").to_string()
}

fn string(value: &str) -> JsonValue {
    JsonValue::String(value.to_string())
}

fn object(fields: Vec<(&str, JsonValue)>) -> JsonValue {
    JsonValue::Object(
        fields
            .into_iter()
            .map(|(key, value)| (key.to_string(), value))
            .collect(),
    )
}

fn rows(bytes: &[u8]) -> Vec<JsonValue> {
    decode_canonical(bytes)
        .expect("the file is in canonical form")
        .as_array()
        .expect("the root is an array")
        .to_vec()
}

fn residuals_of(wire: &JsonValue) -> ResidualSet<String> {
    ResidualSet::new(
        field(wire, "residuals")
            .as_array()
            .expect("residuals is an array")
            .iter()
            .map(text),
    )
}

fn outcome_of(wire: &JsonValue) -> Outcome {
    let value = text(field(wire, "value"));
    match text(field(wire, "kind")).as_str() {
        "resolved" => RefinementOutcome::Resolved(value),
        "residual" => RefinementOutcome::Residual {
            value,
            residuals: residuals_of(wire),
        },
        "stopped" => RefinementOutcome::Stopped {
            value,
            residuals: residuals_of(wire),
            cause: text(field(wire, "cause")),
        },
        kind => panic!("unknown kind {kind}"),
    }
}

fn sorted_residuals(residuals: &ResidualSet<String>) -> JsonValue {
    let mut values: Vec<&String> = residuals.iter().collect();
    values.sort();
    JsonValue::Array(values.into_iter().map(|value| string(value)).collect())
}

fn outcome_json(outcome: &Outcome) -> JsonValue {
    match outcome {
        RefinementOutcome::Resolved(value) => {
            object(vec![("kind", string("resolved")), ("value", string(value))])
        }
        RefinementOutcome::Residual { value, residuals } => object(vec![
            ("kind", string("residual")),
            ("value", string(value)),
            ("residuals", sorted_residuals(residuals)),
        ]),
        RefinementOutcome::Stopped {
            value,
            residuals,
            cause,
        } => object(vec![
            ("kind", string("stopped")),
            ("value", string(value)),
            ("residuals", sorted_residuals(residuals)),
            ("cause", string(cause)),
        ]),
    }
}

fn outcome_row(row: &JsonValue) -> (String, bool, JsonValue) {
    let left = outcome_of(field(row, "left"));
    let right = outcome_of(field(row, "right"));
    let same = left == right;
    let name = text(field(row, "name"));
    let json = object(vec![
        ("name", string(&name)),
        ("left", outcome_json(&left)),
        ("right", outcome_json(&right)),
        ("same", JsonValue::Bool(same)),
    ]);
    (name, same, json)
}

#[test]
fn outcomes_equal_lean_outcomes() {
    let computed: Vec<JsonValue> = rows(CASES).iter().map(|row| outcome_row(row).2).collect();
    let bytes =
        canonical_bytes(&JsonValue::Array(computed)).expect("the outcomes have canonical bytes");
    assert_eq!(bytes, LEAN_OUTCOMES);
}

#[test]
fn cases_have_unique_names_and_both_verdicts() {
    let outcomes: Vec<(String, bool, JsonValue)> = rows(CASES).iter().map(outcome_row).collect();
    let mut names: Vec<&String> = outcomes.iter().map(|(name, _, _)| name).collect();
    names.sort();
    names.dedup();
    assert_eq!(names.len(), outcomes.len());
    assert!(outcomes.iter().any(|(_, same, _)| *same));
    assert!(outcomes.iter().any(|(_, same, _)| !*same));
}

#[test]
fn reordered_inputs_stay_the_same_and_swapped_cases_differ() {
    let outcomes: Vec<(String, bool, JsonValue)> = rows(CASES).iter().map(outcome_row).collect();
    let verdict = |name: &str| {
        outcomes
            .iter()
            .find(|(candidate, _, _)| candidate == name)
            .unwrap_or_else(|| panic!("missing case {name}"))
            .1
    };
    assert!(verdict("residual_order_and_duplicates"));
    assert!(verdict("stopped_order_and_duplicates"));
    for name in [
        "case_resolved_residual",
        "case_residual_stopped",
        "case_resolved_stopped",
    ] {
        assert!(!verdict(name));
    }
}

#[test]
fn an_order_sensitive_comparison_is_detected_as_a_mutation() {
    let disagreements = rows(CASES)
        .iter()
        .filter(|row| {
            let ordered =
                canonical_bytes(field(row, "left")) == canonical_bytes(field(row, "right"));
            ordered != outcome_row(row).1
        })
        .count();
    assert!(disagreements > 0);
}
