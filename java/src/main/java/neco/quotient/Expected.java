package neco.quotient;

import java.util.List;

/**
 * 証明書を照合する期待値。
 *
 * @param ruleRevision 規則のリビジョン
 * @param source 入力の識別子とリビジョン
 * @param coordinate 座標
 * @param observations 観測
 * @param residuals 残余集合
 * @param <S> 入力の識別子の型
 * @param <Rev> 入力のリビジョンの型
 * @param <C> 座標の型
 * @param <Obs> 観測の型
 * @param <R> 残余の型
 */
public record Expected<S, Rev, C, Obs, R>(
        String ruleRevision,
        SourceRef<S, Rev> source,
        C coordinate,
        Obs observations,
        ResidualSet<R> residuals) {

    public Expected {
        residuals = java.util.Objects.requireNonNull(residuals, "residuals");
    }

    public Expected(String ruleRevision, SourceRef<S, Rev> source, C coordinate,
            Obs observations, java.util.Collection<? extends R> residuals) {
        this(ruleRevision, source, coordinate, observations, ResidualSet.of(residuals));
    }
}
