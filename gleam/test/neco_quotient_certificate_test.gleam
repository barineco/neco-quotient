import comparison_checks
import core_checks
import refinement_checks
import refinement_comparison

pub fn main() {
  core_checks.run()
  comparison_checks.run()
  refinement_checks.run()
  refinement_comparison.run()
}
