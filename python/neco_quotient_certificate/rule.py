from dataclasses import InitVar, dataclass, field
from typing import Iterable, Protocol

from .certificate import ProjectionDigest, SourceRef


class Rule[S, Rev, C, Obs, E](Protocol):
    """座標、観測、証拠から入力の射影ダイジェストを再計算する規則。

    返す射影ダイジェストは射影の昇順に並べる。
    """

    def __call__(
        self,
        source: SourceRef[S, Rev],
        coordinate: C,
        observations: Obs,
        evidence: E,
    ) -> tuple[ProjectionDigest, ...]: ...


@dataclass(frozen=True)
class DuplicateRule:
    """表の中で二度以上現れる規則のリビジョン。"""

    rule_revision: str


_TABLE_SEAL = object()


@dataclass(frozen=True, eq=False)
class RuleTable[S, Rev, C, Obs, E]:
    """規則のリビジョンをキーとする規則の表。

    構築時にリビジョンと規則の組を tuple として固定する。RuleTable.of から構築する。
    """

    _entries: tuple[tuple[str, Rule[S, Rev, C, Obs, E]], ...] = field(repr=False)
    _seal: InitVar[object | None] = None

    def __post_init__(self, _seal: object | None) -> None:
        if _seal is not _TABLE_SEAL:
            raise TypeError("RuleTable は RuleTable.of から構築する")

    @classmethod
    def of(
        cls,
        entries: Iterable[tuple[str, Rule[S, Rev, C, Obs, E]]],
    ) -> "RuleTable[S, Rev, C, Obs, E] | DuplicateRule":
        copied = tuple((rule_revision, rule) for rule_revision, rule in entries)
        seen: set[str] = set()
        for rule_revision, _ in copied:
            if rule_revision in seen:
                return DuplicateRule(rule_revision=rule_revision)
            seen.add(rule_revision)
        return cls(copied, _seal=_TABLE_SEAL)

    def lookup(self, rule_revision: str) -> Rule[S, Rev, C, Obs, E] | None:
        for revision, rule in self._entries:
            if revision == rule_revision:
                return rule
        return None
