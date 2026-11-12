package neco.quotient;

import java.util.Collections;
import java.util.Comparator;
import java.util.Map;
import java.util.Objects;
import java.util.SortedMap;
import java.util.TreeMap;

final class Utf8Order {

    static final Comparator<String> COMPARATOR = Utf8Order::compare;

    private Utf8Order() {
    }

    static int compare(String left, String right) {
        int i = 0;
        int j = 0;
        while (i < left.length() && j < right.length()) {
            int a = left.codePointAt(i);
            int b = right.codePointAt(j);
            if (a != b) {
                return Integer.compare(a, b);
            }
            i += Character.charCount(a);
            j += Character.charCount(b);
        }
        return Boolean.compare(i < left.length(), j < right.length());
    }

    static <V> SortedMap<String, V> copy(Map<String, ? extends V> source) {
        Objects.requireNonNull(source, "source");
        SortedMap<String, V> out = new TreeMap<>(COMPARATOR);
        for (Map.Entry<String, ? extends V> entry : source.entrySet()) {
            out.put(Objects.requireNonNull(entry.getKey(), "name"),
                    Objects.requireNonNull(entry.getValue(), "digest"));
        }
        return Collections.unmodifiableSortedMap(out);
    }
}
