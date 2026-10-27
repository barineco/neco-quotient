package neco.quotient;

import java.util.List;

/**
 * 照合の失敗。
 *
 * <p>同一性は操作、段階、入力参照で比べる。期待値と実際の値は診断の表示に限る。
 *
 * @param operation 操作の名前
 * @param stage 不一致の段階
 * @param expected 期待値の診断の表示
 * @param actual 実際の値の診断の表示
 * @param origin 証明書のリビジョンと入力参照
 * @param provenance 呼出し元が渡した来歴
 * @param contributing 寄与した不一致の列
 * @param <P> 来歴の型
 */
public record Mismatch<P>(
        String operation,
        Stage stage,
        String expected,
        String actual,
        Origin origin,
        P provenance,
        List<Mismatch<P>> contributing) {

    public Mismatch {
        contributing = List.copyOf(contributing);
    }

    /**
     * 不一致の診断の文を返す。
     *
     * @return 操作、段階、リビジョンと入力を含む文
     */
    public String describe() {
        return operation + " failed at stage " + stage.label()
                + ": expected " + expected
                + ", actual " + actual
                + " (rule " + origin.ruleRevision()
                + ", source " + origin.sourceIdentity() + "@" + origin.sourceRevision() + ")";
    }
}
