from dataclasses import dataclass
from typing import Literal


type Stage = Literal["decode", "source", "coordinate", "observations", "digest", "residual"]


@dataclass(frozen=True)
class Origin:
    """不一致の対象となる証明書の規則のリビジョンと入力。"""

    rule_revision: str
    source_identity: str
    source_revision: str


@dataclass(frozen=True)
class Mismatch[P]:
    """照合の失敗。

    provenance は呼び出す側が渡した値をそのまま保つ。
    contributing は下位の不一致の列で、単独の不一致では空の tuple とする。
    """

    operation: str
    stage: Stage
    expected: str
    actual: str
    origin: Origin
    provenance: P
    contributing: tuple[Mismatch[P], ...] = ()
