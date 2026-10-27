package neco.quotient;

import java.util.List;

/**
 * 座標、観測、証拠から入力の射影ダイジェストを再計算する規則。
 *
 * <p>返す射影ダイジェストの列は射影の昇順に並べる。
 *
 * @param <S> 入力の識別子の型
 * @param <Rev> 入力のリビジョンの型
 * @param <C> 座標の型
 * @param <Obs> 観測の型
 * @param <E> 証拠の型
 */
@FunctionalInterface
public interface Rule<S, Rev, C, Obs, E> {

    /**
     * 射影ダイジェストを再計算する。
     *
     * @param source 入力の識別子とリビジョン
     * @param coordinate 座標
     * @param observations 観測
     * @param evidence 証拠
     * @return 射影ダイジェストの列
     */
    List<ProjectionDigest> recompute(SourceRef<S, Rev> source, C coordinate, Obs observations, E evidence);
}
