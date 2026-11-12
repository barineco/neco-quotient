from collections.abc import Iterable
from dataclasses import dataclass

from .certificate import ResidualSet

@dataclass(frozen=True)
class Resolved[V]:

    value: V

@dataclass(frozen=True)
class Residual[V, R]:

    value: V
    residuals: ResidualSet[R] | Iterable[R]

    def __post_init__(self) -> None:
        object.__setattr__(self, "residuals", ResidualSet(self.residuals))

@dataclass(frozen=True)
class Stopped[V, R, S]:

    value: V
    residuals: ResidualSet[R] | Iterable[R]
    cause: S

    def __post_init__(self) -> None:
        object.__setattr__(self, "residuals", ResidualSet(self.residuals))

type RefinementOutcome[V, R, S] = Resolved[V] | Residual[V, R] | Stopped[V, R, S]
