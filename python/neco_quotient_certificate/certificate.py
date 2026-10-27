from dataclasses import dataclass


@dataclass(frozen=True, init=False, eq=False)
class ResidualSet[R]:
    """要素の所属で同一性を決める残余集合。"""

    values: tuple[R, ...]

    def __init__(self, values) -> None:
        unique: list[R] = []
        for value in values:
            if not any(value == item for item in unique):
                unique.append(value)
        object.__setattr__(self, "values", tuple(unique))

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, ResidualSet):
            return NotImplemented
        return len(self.values) == len(other.values) and all(
            any(value == item for item in other.values) for value in self.values
        )

    def __iter__(self):
        return iter(self.values)

    def __repr__(self) -> str:
        return f"ResidualSet({self.values!r})"


@dataclass(frozen=True)
class SourceRef[S, Rev]:
    """証明書が記述する入力の識別子とリビジョン。"""

    identity: S
    revision: Rev


@dataclass(frozen=True)
class WithinRuntime:
    """同じ実行系の中でだけ 射影ダイジェストを比べられる範囲。"""

    name: str


@dataclass(frozen=True)
class CrossLanguage:
    """言語をまたいで 射影ダイジェストを比べられる範囲。"""

    name: str


type DigestScope = WithinRuntime | CrossLanguage


@dataclass(frozen=True)
class ProjectionDigest:
    """入力の一つの射影ダイジェスト。"""

    projection: str
    digest: str
    scope: DigestScope


@dataclass(frozen=True)
class Certificate[S, Rev, C, Obs, R, E]:
    """照合に提出する証明書。

    構築時に digests を tuple へ写し、residuals を集合として保つ。
    """

    rule_revision: str
    source: SourceRef[S, Rev]
    coordinate: C
    digests: tuple[ProjectionDigest, ...]
    residuals: ResidualSet[R]
    observations: Obs
    evidence: E

    def __post_init__(self) -> None:
        object.__setattr__(self, "digests", tuple(self.digests))
        object.__setattr__(self, "residuals", ResidualSet(self.residuals))


@dataclass(frozen=True)
class Expected[S, Rev, C, Obs, R]:
    """証明書を照合する期待値。

    構築時に residuals を集合として保つ。
    """

    rule_revision: str
    source: SourceRef[S, Rev]
    coordinate: C
    observations: Obs
    residuals: ResidualSet[R]

    def __post_init__(self) -> None:
        object.__setattr__(self, "residuals", ResidualSet(self.residuals))
