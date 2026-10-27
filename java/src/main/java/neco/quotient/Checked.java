package neco.quotient;

import java.util.List;
import java.util.Objects;

/**
 * 照合を通過した証明書。
 *
 * <p>照合に用いた表を保持する。作成できるのは {@link #admit} だけである。
 *
 * @param <S> 入力の識別子の型
 * @param <Rev> 入力のリビジョンの型
 * @param <C> 座標の型
 * @param <Obs> 観測の型
 * @param <R> 残余の型
 * @param <E> 証拠の型
 */
public final class Checked<S, Rev, C, Obs, R, E> {

    private final RuleTable<S, Rev, C, Obs, E> table;
    private final Certificate<S, Rev, C, Obs, R, E> certificate;
    private final List<ProjectionDigest> recomputed;

    Checked(
            RuleTable<S, Rev, C, Obs, E> table,
            Certificate<S, Rev, C, Obs, R, E> certificate,
            List<ProjectionDigest> recomputed) {
        this.table = table;
        this.certificate = certificate;
        this.recomputed = List.copyOf(recomputed);
    }

    /**
     * 証明書を期待値と照合する。
     *
     * <p>段階はリビジョンの不一致、表の検索、入力、座標、観測、射影ダイジェスト、残余の順に検査する。
     * リビジョンの不一致と表の検索の失敗は decode の段階に報告する。
     * 成功は {@link Result.Accepted}、失敗は {@link Result.Rejected} の {@link Mismatch} で返す。
     *
     * @param table 規則の表
     * @param certificate 照合する証明書
     * @param expected 期待値
     * @param provenance 呼出し元の来歴。不一致へそのまま渡す
     * @param <S> 入力の識別子の型
     * @param <Rev> 入力のリビジョンの型
     * @param <C> 座標の型
     * @param <Obs> 観測の型
     * @param <R> 残余の型
     * @param <E> 証拠の型
     * @param <P> 来歴の型
     * @return 照合の結果
     */
    public static <S, Rev, C, Obs, R, E, P> Result<Checked<S, Rev, C, Obs, R, E>, Mismatch<P>> admit(
            RuleTable<S, Rev, C, Obs, E> table,
            Certificate<S, Rev, C, Obs, R, E> certificate,
            Expected<S, Rev, C, Obs, R> expected,
            P provenance) {
        Objects.requireNonNull(table, "table");
        Objects.requireNonNull(certificate, "certificate");
        Objects.requireNonNull(expected, "expected");
        if (!certificate.ruleRevision().equals(expected.ruleRevision())) {
            return reject(certificate, Stage.DECODE,
                    expected.ruleRevision(), certificate.ruleRevision(), provenance);
        }
        var found = table.lookup(certificate.ruleRevision());
        if (found.isEmpty()) {
            return reject(certificate, Stage.DECODE,
                    "rule in table", certificate.ruleRevision(), provenance);
        }
        if (!certificate.source().equals(expected.source())) {
            return reject(certificate, Stage.SOURCE,
                    sourceText(expected.source()), sourceText(certificate.source()), provenance);
        }
        if (!Objects.equals(certificate.coordinate(), expected.coordinate())) {
            return reject(certificate, Stage.COORDINATE,
                    String.valueOf(expected.coordinate()), String.valueOf(certificate.coordinate()),
                    provenance);
        }
        if (!Objects.equals(certificate.observations(), expected.observations())) {
            return reject(certificate, Stage.OBSERVATIONS,
                    String.valueOf(expected.observations()), String.valueOf(certificate.observations()),
                    provenance);
        }
        List<ProjectionDigest> recomputed = found.get().recompute(
                certificate.source(), certificate.coordinate(), certificate.observations(), certificate.evidence());
        if (!certificate.digests().equals(recomputed)) {
            return reject(certificate, Stage.DIGEST,
                    String.valueOf(recomputed), String.valueOf(certificate.digests()), provenance);
        }
        if (!certificate.residuals().equals(expected.residuals())) {
            return reject(certificate, Stage.RESIDUAL,
                    String.valueOf(expected.residuals()), String.valueOf(certificate.residuals()),
                    provenance);
        }
        return new Result.Accepted<>(new Checked<>(table, certificate, recomputed));
    }

    /**
     * 照合を通過した証明書を返す。
     *
     * @return 証明書
     */
    public Certificate<S, Rev, C, Obs, R, E> certificate() {
        return certificate;
    }

    /**
     * 証明書の入力の識別子とリビジョンを返す。
     *
     * @return 入力の識別子とリビジョン
     */
    public SourceRef<S, Rev> source() {
        return certificate.source();
    }

    /**
     * 照合の際に再計算した射影ダイジェストの列を返す。
     *
     * @return 射影ダイジェストの列
     */
    public List<ProjectionDigest> recomputed() {
        return recomputed;
    }

    private static <S, Rev, C, Obs, R, E, P> Result<Checked<S, Rev, C, Obs, R, E>, Mismatch<P>> reject(
            Certificate<S, Rev, C, Obs, R, E> certificate,
            Stage stage,
            String expected,
            String actual,
            P provenance) {
        Origin origin = new Origin(
                certificate.ruleRevision(),
                String.valueOf(certificate.source().identity()),
                String.valueOf(certificate.source().revision()));
        return new Result.Rejected<>(
                new Mismatch<>("admit", stage, expected, actual, origin, provenance, List.of()));
    }

    private static <S, Rev> String sourceText(SourceRef<S, Rev> source) {
        return source.identity() + "@" + source.revision();
    }
}
