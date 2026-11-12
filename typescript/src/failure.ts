import type { AdmissionChecks, Condition, Status } from "./checks.ts";
import { CONDITIONS } from "./checks.ts";

export type Origin = {
  readonly ruleRevision: string;
  readonly sourceIdentity: string;
  readonly sourceRevision: string;
};

export type ConditionFailure<C extends Condition, P> = {
  readonly condition: C;
  readonly operation: "admit";
  readonly expected: string;
  readonly actual: string;
  readonly origin: Origin;
  readonly provenance: P;
};

type SealMismatch = <P>(checks: AdmissionChecks<P>) => Mismatch<P>;

let sealMismatch!: SealMismatch;

export class Mismatch<P> {
  readonly #checks: AdmissionChecks<P>;

  private constructor(checks: AdmissionChecks<P>) {
    if (checks.allMatched()) {
      throw new TypeError("a mismatch holds at least one failing condition");
    }
    this.#checks = checks;
    Object.freeze(this);
  }

  static {
    sealMismatch = (checks) => new Mismatch(checks);
  }

  get checks(): AdmissionChecks<P> {
    return this.#checks;
  }

  get origin(): Origin {
    return this.#checks.origin;
  }

  get provenance(): P {
    return this.#checks.provenance;
  }

  statusAt(condition: Condition): Status<P> {
    return this.#checks.statusAt(condition);
  }

  toString(): string {
    const failed = CONDITIONS.filter((condition) => this.statusAt(condition).kind === "mismatched");
    const { ruleRevision, sourceIdentity, sourceRevision } = this.origin;
    return `admit failed at ${failed.join(", ")}: rule ${ruleRevision}, source ${sourceIdentity}@${sourceRevision}`;
  }
}

export function newMismatch<P>(checks: AdmissionChecks<P>): Mismatch<P> {
  return sealMismatch(checks);
}
