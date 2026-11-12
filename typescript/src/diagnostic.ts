export function describeList(values: readonly unknown[]): string {
  return `[${values.map((value) => String(value)).join(", ")}]`;
}
