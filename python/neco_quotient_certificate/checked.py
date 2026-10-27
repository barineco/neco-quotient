from dataclasses import InitVar, dataclass, field

from .certificate import Certificate, ProjectionDigest, SourceRef
from .rule import RuleTable


_CHECK_SEAL = object()


@dataclass(frozen=True)
class Checked[S, Rev, C, Obs, R, E]:
    """照合を通過した証明書。

    再計算した射影ダイジェストの列と、照合に用いた表への関係を持つ。admit だけが構築する。
    """

    certificate: Certificate[S, Rev, C, Obs, R, E]
    recomputed: tuple[ProjectionDigest, ...]
    _table: RuleTable[S, Rev, C, Obs, E] = field(repr=False)
    _seal: InitVar[object | None] = None

    def __post_init__(self, _seal: object | None) -> None:
        if _seal is not _CHECK_SEAL:
            raise TypeError("Checked は admit だけが構築する")

    @property
    def source(self) -> SourceRef[S, Rev]:
        return self.certificate.source
