package neco.quotient;

/**
 * 証明書が記述する入力の識別子とリビジョン。
 *
 * @param identity 入力の識別子
 * @param revision 入力のリビジョン
 * @param <S> 識別子の型
 * @param <Rev> リビジョンの型
 */
public record SourceRef<S, Rev>(S identity, Rev revision) {
}
