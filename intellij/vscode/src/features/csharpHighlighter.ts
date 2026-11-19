import * as vscode from 'vscode';
import { isThemeActive, setting } from '../config';
import { AwaitableCache, parseAwaitableHover } from '../csharp/awaitable';
import { asyncTypeSpans, attributeSpans, type CallSite, callSites, declaredTypeNames, identifiers, maskCode, type Span } from '../csharp/codeScan';
import { documentSymbols, hoverText } from '../lsp';
import { documentLines, flatten, onScreen, visibleEditors } from '../symbols';
import { KeyedDebouncer } from '../util/keyedDebouncer';
import { type RequestLimiter } from '../util/requestLimiter';

const REFRESH_DELAY_MS = 300;
const VIEWPORT_MARGIN_LINES = 40;
const UNANSWERED_RETRY_MS = 5000;
const DECLARATION_KINDS: ReadonlySet<vscode.SymbolKind> = new Set([vscode.SymbolKind.Method, vscode.SymbolKind.Constructor]);

/** What one version of a document contains; recomputed only when the text changes. */
interface Scan {
  readonly version: number;
  readonly masked: string[];
  readonly attributes: Span[];
  readonly asyncTypes: Span[];
  /** Method and constructor names; undefined until the language server has answered. */
  declarations: vscode.Range[] | undefined;
  calls: CallSite[] | undefined;
}

/**
 * C# colors a theme can't express. The C# server tags method declarations and calls alike and doesn't report
 * return types, so declarations (yellow), attribute names (olive) and async code (blue) are decorations.
 * Each has a dark-theme and a light-theme color; VS Code picks the one matching the active theme's kind.
 * Whether a call returns an awaitable comes from the server's hover, asked only for calls on screen and cached.
 */
export class CSharpHighlighter implements vscode.Disposable {
  private readonly declarationType = colorDecoration('#FFC66D', '#00627A');
  private readonly attributeType = colorDecoration('#BBB529', '#9E880D');
  private readonly asyncType = colorDecoration('#5394EC', '#2E6FD8');
  private readonly scans = new Map<string, Scan>();
  private readonly awaitable = new AwaitableCache(UNANSWERED_RETRY_MS);
  // Identifiers on lines edited since each document's last save; they decide which answers a save invalidates.
  private readonly editedWords = new Map<string, Set<string>>();
  private readonly running = new Map<string, vscode.CancellationTokenSource>();
  private readonly debouncer = new KeyedDebouncer(REFRESH_DELAY_MS);
  private readonly disposables: vscode.Disposable[];

  constructor(private readonly limiter: RequestLimiter, private readonly log: vscode.LogOutputChannel) {
    this.disposables = [
      this.declarationType,
      this.attributeType,
      this.asyncType,
      vscode.window.onDidChangeVisibleTextEditors(() => this.scheduleVisible()),
      vscode.window.onDidChangeTextEditorVisibleRanges((e) => this.schedule(e.textEditor.document)),
      vscode.workspace.onDidChangeTextDocument((e) => this.onChange(e)),
      vscode.workspace.onDidSaveTextDocument((document) => this.onSave(document)),
      vscode.workspace.onDidCloseTextDocument((document) => this.forget(document)),
      // The server publishes diagnostics once it has analyzed a file, so its answers are ready by then.
      vscode.languages.onDidChangeDiagnostics((e) => {
        const changed = new Set(e.uris.map((uri) => uri.toString()));
        vscode.window.visibleTextEditors
          .filter((editor) => changed.has(editor.document.uri.toString()))
          .forEach((editor) => this.schedule(editor.document));
      }),
      vscode.workspace.onDidChangeConfiguration((e) => {
        if (e.affectsConfiguration('workbench.colorTheme') || e.affectsConfiguration('musclememory.csharp')) {
          this.scheduleVisible();
        }
      }),
    ];
    this.scheduleVisible();
  }

  dispose(): void {
    this.debouncer.dispose();
    for (const cancellation of this.running.values()) {
      cancellation.cancel();
    }
    vscode.Disposable.from(...this.disposables).dispose();
  }

  private scheduleVisible(): void {
    vscode.window.visibleTextEditors.forEach((editor) => this.schedule(editor.document));
  }

  private schedule(document: vscode.TextDocument): void {
    if (document.languageId !== 'csharp') {
      return;
    }
    this.debouncer.schedule(document.uri.toString(), () => {
      this.refresh(document).catch((error: unknown) => this.log.error(`C# highlighting failed for ${document.uri.fsPath}`, error));
    });
  }

  private async refresh(document: vscode.TextDocument): Promise<void> {
    const editors = visibleEditors(document);
    if (editors.length === 0) {
      return;
    }
    if (!isThemeActive()) {
      editors.forEach((editor) => this.clear(editor));
      return;
    }
    const key = document.uri.toString();
    this.running.get(key)?.cancel();
    const cancellation = new vscode.CancellationTokenSource();
    this.running.set(key, cancellation);
    const token = cancellation.token;
    try {
      const scan = this.scanOf(document);
      if (scan.declarations === undefined) {
        const symbols = await this.limiter.run(() => documentSymbols(document.uri), token);
        if (token.isCancellationRequested || document.version !== scan.version) {
          return;
        }
        // No outline at all means the server hasn't loaded the file yet: ask again on the next refresh.
        if (symbols && symbols.length > 0) {
          scan.declarations = flatten(symbols).filter((s) => DECLARATION_KINDS.has(s.kind)).map((s) => s.selectionRange);
        }
      }
      this.apply(editors, document, scan);
      if (await this.resolveVisibleCalls(document, scan, editors, token) && !token.isCancellationRequested) {
        this.apply(visibleEditors(document), document, scan);
      }
    } finally {
      if (this.running.get(key) === cancellation) {
        this.running.delete(key);
      }
      cancellation.dispose();
    }
  }

  private scanOf(document: vscode.TextDocument): Scan {
    const key = document.uri.toString();
    const cached = this.scans.get(key);
    if (cached?.version === document.version) {
      return cached;
    }
    const masked = maskCode(documentLines(document));
    const scan: Scan = {
      version: document.version,
      masked,
      attributes: attributeSpans(masked),
      asyncTypes: asyncTypeSpans(masked),
      declarations: undefined,
      calls: undefined,
    };
    this.scans.set(key, scan);
    return scan;
  }

  /** Calls in the document, once declarations are known (so declarations aren't mistaken for calls). */
  private callsOf(scan: Scan): CallSite[] {
    if (!scan.declarations || !setting('csharp.awaitableCalls', true)) {
      return [];
    }
    if (!scan.calls) {
      const declared = new Set(scan.declarations.map((range) => `${range.start.line}:${range.start.character}`));
      scan.calls = callSites(scan.masked, (line, start) => declared.has(`${line}:${start}`));
    }
    return scan.calls;
  }

  /** Asks the server about calls on screen it hasn't answered yet. Returns whether anything was asked. */
  private async resolveVisibleCalls(document: vscode.TextDocument, scan: Scan, editors: readonly vscode.TextEditor[],
    token: vscode.CancellationToken): Promise<boolean> {
    const uri = document.uri.toString();
    const shown = onScreen(editors, VIEWPORT_MARGIN_LINES);
    const wanted = this.callsOf(scan)
      .filter((site) => this.awaitable.needsAnswer(uri, site.key) && site.spans.some((span) => shown(span.line)));
    if (wanted.length === 0) {
      return false;
    }
    await Promise.all(wanted.map((site) => this.limiter.run(async () => {
      const span = site.spans.find((s) => shown(s.line)) ?? site.spans[0];
      try {
        const hover = await hoverText(document.uri, new vscode.Position(span.line, span.start + 1));
        this.awaitable.record(uri, site, parseAwaitableHover(hover, site.method));
      } catch {
        this.awaitable.record(uri, site, undefined);
      }
    }, token)));
    return true;
  }

  private apply(editors: readonly vscode.TextEditor[], document: vscode.TextDocument, scan: Scan): void {
    const uri = document.uri.toString();
    const awaitableCalls = this.callsOf(scan)
      .filter((site) => this.awaitable.get(uri, site.key)?.awaitable)
      .flatMap((site) => site.spans);
    const asyncRanges = [...scan.asyncTypes, ...awaitableCalls].map(toRange);
    const attributeRanges = scan.attributes.map(toRange);
    for (const editor of editors) {
      editor.setDecorations(this.declarationType, scan.declarations ?? []);
      editor.setDecorations(this.attributeType, attributeRanges);
      editor.setDecorations(this.asyncType, asyncRanges);
    }
  }

  private clear(editor: vscode.TextEditor): void {
    for (const type of [this.declarationType, this.attributeType, this.asyncType]) {
      editor.setDecorations(type, []);
    }
  }

  private onChange(event: vscode.TextDocumentChangeEvent): void {
    const { document } = event;
    if (document.languageId !== 'csharp' || event.contentChanges.length === 0) {
      return;
    }
    const key = document.uri.toString();
    let words = this.editedWords.get(key);
    if (!words) {
      words = new Set();
      this.editedWords.set(key, words);
    }
    for (const change of event.contentChanges) {
      const first = Math.min(change.range.start.line, document.lineCount - 1);
      const last = Math.min(document.lineCount - 1, first + change.text.split('\n').length - 1);
      for (let line = first; line <= last; line++) {
        for (const word of identifiers(document.lineAt(line).text)) {
          words.add(word);
        }
      }
    }
    this.schedule(document);
  }

  // With auto-save this runs after every pause in typing, so it only drops answers the edits could have changed.
  private onSave(document: vscode.TextDocument): void {
    if (document.languageId !== 'csharp') {
      return;
    }
    const key = document.uri.toString();
    const edited = this.editedWords.get(key);
    this.editedWords.delete(key);
    if (!edited || edited.size === 0) {
      return;
    }
    const dropped = this.awaitable.invalidateAfterSave(key, edited, declaredTypeNames(this.scanOf(document).masked));
    if (dropped > 0) {
      this.log.debug(`${vscode.workspace.asRelativePath(document.uri)} saved: rechecking ${dropped} async call(s)`);
      this.scheduleVisible();
    }
  }

  private forget(document: vscode.TextDocument): void {
    const key = document.uri.toString();
    this.scans.delete(key);
    this.editedWords.delete(key);
    this.awaitable.forget(key);
  }
}

function colorDecoration(dark: string, light: string): vscode.TextEditorDecorationType {
  return vscode.window.createTextEditorDecorationType({ dark: { color: dark }, light: { color: light } });
}

function toRange(span: Span): vscode.Range {
  return new vscode.Range(span.line, span.start, span.line, span.end);
}
