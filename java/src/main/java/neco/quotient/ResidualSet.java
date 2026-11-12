package neco.quotient;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Objects;

public final class ResidualSet<T> {

    private final List<T> values;

    private ResidualSet(Collection<? extends T> values) {
        var unique = new ArrayList<T>();
        for (T value : values) {
            if (unique.stream().noneMatch(existing -> Objects.equals(existing, value))) {
                unique.add(value);
            }
        }
        this.values = List.copyOf(unique);
    }

    public static <T> ResidualSet<T> of(Collection<? extends T> values) {
        return new ResidualSet<>(values);
    }

    public List<T> values() {
        return values;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (!(other instanceof ResidualSet<?> residualSet) || values.size() != residualSet.values.size()) {
            return false;
        }
        return values.stream().allMatch(value -> residualSet.values.stream()
                .anyMatch(candidate -> Objects.equals(value, candidate)));
    }

    @Override
    public int hashCode() {
        return values.stream().mapToInt(Objects::hashCode).sum();
    }

    @Override
    public String toString() {
        return values.toString();
    }
}
