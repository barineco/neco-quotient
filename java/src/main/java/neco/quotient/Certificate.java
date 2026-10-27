package neco.quotient;

import java.util.List;
import java.util.Objects;

/**
 * 照合に提出する証明書。
 *
 * <p>射影ダイジェストは構築時に複製し、残余集合は要素の所属で比較する。
 *
 * @param ruleRevision 規則のリビジョン
 * @param source 入力の識別子とリビジョン
 * @param coordinate 座標
 * @param digests 射影ダイジェストの列
 * @param residuals 残余集合
 * @param observations 観測
 * @param evidence 証拠
 * @param <S> 入力の識別子の型
 * @param <Rev> 入力のリビジョンの型
 * @param <C> 座標の型
 * @param <Obs> 観測の型
 * @param <R> 残余の型
 * @param <E> 証拠の型
 */
public record Certificate<S, Rev, C, Obs, R, E>(
        String ruleRevision,
        SourceRef<S, Rev> source,
        C coordinate,
        List<ProjectionDigest> digests,
        ResidualSet<R> residuals,
        Obs observations,
        E evidence) {

    public Certificate {
        digests = List.copyOf(digests);
        residuals = Objects.requireNonNull(residuals, "residuals");
    }

    public Certificate(String ruleRevision, SourceRef<S, Rev> source, C coordinate,
            List<ProjectionDigest> digests, java.util.Collection<? extends R> residuals,
            Obs observations, E evidence) {
        this(ruleRevision, source, coordinate, digests, ResidualSet.of(residuals), observations, evidence);
    }
}
