package neco.quotient;

import java.util.Objects;

public sealed interface DigestScope permits DigestScope.WithinRuntime, DigestScope.CrossLanguage {

    String payload();

    record WithinRuntime(String payload) implements DigestScope {
        public WithinRuntime {
            Objects.requireNonNull(payload, "payload");
        }
    }

    record CrossLanguage(String payload) implements DigestScope {
        public CrossLanguage {
            Objects.requireNonNull(payload, "payload");
        }
    }
}
