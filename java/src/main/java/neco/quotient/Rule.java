package neco.quotient;

import java.util.Map;

@FunctionalInterface
public interface Rule<S, Rev, C, Obs, E> {

    Map<String, ProjectionDigest> recompute(SourceRef<S, Rev> source, C coordinate, Obs observations, E evidence);
}
