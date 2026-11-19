import * as vscode from 'vscode';

export const TYPE_KINDS: ReadonlySet<vscode.SymbolKind> = new Set([
  vscode.SymbolKind.Class,
  vscode.SymbolKind.Interface,
  vscode.SymbolKind.Struct,
  vscode.SymbolKind.Enum,
  vscode.SymbolKind.Object,
]);

/** Members that can implement or override another member. */
export const MEMBER_KINDS: ReadonlySet<vscode.SymbolKind> = new Set([
  vscode.SymbolKind.Method,
  vscode.SymbolKind.Function,
  vscode.SymbolKind.Property,
  vscode.SymbolKind.Event,
]);

export function flatten(symbols: readonly vscode.DocumentSymbol[]): vscode.DocumentSymbol[] {
  return symbols.flatMap((symbol) => [symbol, ...flatten(symbol.children)]);
}

/** Outermost-to-innermost symbols containing the position. */
export function enclosingSymbols(symbols: readonly vscode.DocumentSymbol[], position: vscode.Position): vscode.DocumentSymbol[] {
  const path: vscode.DocumentSymbol[] = [];
  let level = symbols;
  for (;;) {
    const hit = level.find((symbol) => symbol.range.contains(position));
    if (!hit) {
      return path;
    }
    path.push(hit);
    level = hit.children;
  }
}

export function documentLines(document: vscode.TextDocument): string[] {
  return document.getText().split(/\r?\n/);
}

export function visibleEditors(document: vscode.TextDocument): vscode.TextEditor[] {
  return vscode.window.visibleTextEditors.filter((editor) => editor.document === document);
}

/** Whether a line is on screen in any of the editors, give or take `marginLines`. */
export function onScreen(editors: readonly vscode.TextEditor[], marginLines: number): (line: number) => boolean {
  const ranges = editors.flatMap((editor) => editor.visibleRanges)
    .map((range) => [range.start.line - marginLines, range.end.line + marginLines] as const);
  return (line) => ranges.some(([from, to]) => line >= from && line <= to);
}
