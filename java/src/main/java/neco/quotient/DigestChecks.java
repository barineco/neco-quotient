package neco.quotient;

import java.util.Collections;
import java.util.HashSet;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.SortedMap;
import java.util.TreeMap;

public final class DigestChecks {

    private final SortedMap<String, ProjectionResult> results;

    private DigestChecks(SortedMap<String, ProjectionResult> results) {
        this.results = results;
    }

    static DigestChecks check(Map<String, ProjectionDigest> expected, Map<String, ProjectionDigest> actual) {
        Set<String> names = new HashSet<>(expected.keySet());
        names.addAll(actual.keySet());
        SortedMap<String, ProjectionResult> out = new TreeMap<>(Utf8Order.COMPARATOR);
        for (String name : names) {
            out.put(name, ProjectionResult.of(expected.get(name), actual.get(name)));
        }
        return new DigestChecks(Collections.unmodifiableSortedMap(out));
    }

    public SortedMap<String, ProjectionResult> results() {
        return results;
    }

    public Optional<ProjectionResult> get(String name) {
        return Optional.ofNullable(results.get(name));
    }

    public boolean allMatched() {
        return results.values().stream().allMatch(ProjectionResult::isMatched);
    }
}
