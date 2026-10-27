package neco.quotient;

/**
 * 成功と失敗を表す閉じた和。
 *
 * @param <V> 成功の値の型
 * @param <E> 失敗の値の型
 */
public sealed interface Result<V, E> permits Result.Accepted, Result.Rejected {

    /**
     * 成功を表す。
     *
     * @param value 成功の値
     * @param <V> 成功の値の型
     * @param <E> 失敗の値の型
     */
    record Accepted<V, E>(V value) implements Result<V, E> {
    }

    /**
     * 失敗を表す。
     *
     * @param error 失敗の値
     * @param <V> 成功の値の型
     * @param <E> 失敗の値の型
     */
    record Rejected<V, E>(E error) implements Result<V, E> {
    }
}
