/**
 * Outline names carry signatures ("GetOrder(string, CancellationToken) : Task<Order>", "Foo<T>",
 * "Name : string"); members are matched by their bare name.
 */
export function baseName(symbolName: string): string {
  return symbolName.replace(/[(<:].*$/, '').trim();
}
