from collections.abc import Mapping
from dataclasses import InitVar, dataclass, field

from .certificate import Certificate, Expected, ProjectionDigest, SourceRef
from .rule import RuleTable

_CHECK_SEAL = object()

@dataclass(frozen=True)
class Checked[S, Rev, C, Obs, R, E]:

    certificate: Certificate[S, Rev, C, Obs, R, E]
    expected: Expected[S, Rev, C, Obs, R]
    recomputed: Mapping[str, ProjectionDigest]
    _table: RuleTable[S, Rev, C, Obs, E] = field(repr=False, compare=False)
    _seal: InitVar[object | None] = None

    def __post_init__(self, _seal: object | None) -> None:
        if _seal is not _CHECK_SEAL:
            raise TypeError("Checked は admit だけが構築する")

    @property
    def source(self) -> SourceRef[S, Rev]:
        return self.certificate.source
