import * as vscode from 'vscode';
import { setting } from '../config';
import { MARKER_ICONS, type MarkerIcon, markerHoverMarkdown, markerIcon } from '../inheritance/markerModel';
import { type DocumentModel, INHERITANCE_LANGUAGES, type InheritanceModels } from '../inheritance/models';
import { OPEN_LOCATION_COMMAND } from '../inheritance/targets';
import { onScreen, visibleEditors } from '../symbols';
import { KeyedDebouncer } from '../util/keyedDebouncer';

const REFRESH_DELAY_MS = 500;
const VIEWPORT_MARGIN_LINES = 40;
const MAX_HOVER_LINKS = 10;
// CSS background-size within the gutter cell: about the height of CodeLens text such as "9 references".
const GUTTER_ICON_SIZE = '55%';
// Lines (1-based) of the active editor with ↑ or ↓ markers; the gutter's right-click menu shows its items there.
const SUPER_LINES_CONTEXT = 'musclememory.superLines';
const INHERITOR_LINES_CONTEXT = 'musclememory.inheritorLines';

/**
 * IntelliJ IDEA's gutter markers: ↑ implements/overrides, ↓ is implemented/overridden; green for interfaces,
 * blue for classes. VS Code doesn't pass left clicks on gutter icons to extensions, so the markers come with
 * hover links, a right-click menu on the gutter and (in InheritanceCodeLens) clickable lines.
 */
export class InheritanceMarkers implements vscode.Disposable {
  private readonly decorationTypes: ReadonlyMap<MarkerIcon, vscode.TextEditorDecorationType>;
  // Which model each editor shows; editors move their markers with edits, so they are redrawn only when needed.
  private readonly shown = new WeakMap<vscode.TextEditor, DocumentModel>();
  private readonly running = new Map<string, vscode.CancellationTokenSource>();
  private readonly debouncer = new KeyedDebouncer(REFRESH_DELAY_MS);
  private readonly disposables: vscode.Disposable[];

  constructor(context: vscode.ExtensionContext, private readonly models: InheritanceModels, private readonly log: vscode.LogOutputChannel) {
    this.decorationTypes = new Map(MARKER_ICONS.map((icon) => [icon, vscode.window.createTextEditorDecorationType({
      gutterIconPath: context.asAbsolutePath(`icons/${icon}.svg`),
      gutterIconSize: GUTTER_ICON_SIZE,
    })]));
    this.disposables = [
      ...this.decorationTypes.values(),
      vscode.window.onDidChangeVisibleTextEditors(() => this.scheduleVisible()),
      vscode.window.onDidChangeTextEditorVisibleRanges((e) => this.schedule(e.textEditor.document)),
      vscode.window.onDidChangeActiveTextEditor(() => this.updateLineContext()),
      vscode.workspace.onDidChangeTextDocument((e) => this.schedule(e.document)),
      models.onDidChange(() => this.scheduleVisible()),
      vscode.workspace.onDidChangeConfiguration((e) => {
        if (e.affectsConfiguration('musclememory.inheritanceMarkers')) {
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

  private enabled(): boolean {
    return setting('inheritanceMarkers', true);
  }

  private scheduleVisible(): void {
    vscode.window.visibleTextEditors.forEach((editor) => this.schedule(editor.document));
  }

  private schedule(document: vscode.TextDocument): void {
    if (!INHERITANCE_LANGUAGES.has(document.languageId)) {
      return;
    }
    this.debouncer.schedule(document.uri.toString(), () => {
      this.refresh(document).catch((error: unknown) => this.log.error(`Inheritance markers failed for ${document.uri.fsPath}`, error));
    });
  }

  private async refresh(document: vscode.TextDocument): Promise<void> {
    const editors = visibleEditors(document);
    if (editors.length === 0) {
      return;
    }
    if (!this.enabled()) {
      editors.forEach((editor) => this.clear(editor));
      this.updateLineContext();
      return;
    }
    const key = document.uri.toString();
    this.running.get(key)?.cancel();
    const cancellation = new vscode.CancellationTokenSource();
    this.running.set(key, cancellation);
    const token = cancellation.token;
    try {
      const model = await this.models.get(document);
      if (!model || token.isCancellationRequested || model.version !== document.version) {
        return;
      }
      this.apply(editors.filter((editor) => this.shown.get(editor) !== model), model);
      const shown = onScreen(editors, VIEWPORT_MARGIN_LINES);
      const onScreenMembers = model.types.flatMap((type) => type.members)
        .filter((member) => shown(member.symbol.selectionRange.start.line));
      if (await this.models.resolveDown(document, onScreenMembers, token) && !token.isCancellationRequested) {
        this.apply(visibleEditors(document), model);
      }
    } finally {
      if (this.running.get(key) === cancellation) {
        this.running.delete(key);
      }
      cancellation.dispose();
    }
  }

  private apply(editors: readonly vscode.TextEditor[], model: DocumentModel): void {
    const byIcon = new Map<MarkerIcon, vscode.DecorationOptions[]>(MARKER_ICONS.map((icon) => [icon, []]));
    for (const { range, relations } of this.models.marks(model)) {
      if (relations.up.length === 0 && relations.down.length === 0) {
        continue; // implementations not looked up yet
      }
      const hover = new vscode.MarkdownString(markerHoverMarkdown(relations, OPEN_LOCATION_COMMAND, MAX_HOVER_LINKS));
      hover.isTrusted = { enabledCommands: [OPEN_LOCATION_COMMAND] };
      byIcon.get(markerIcon(relations))?.push({ range, hoverMessage: hover });
    }
    for (const editor of editors) {
      for (const [icon, options] of byIcon) {
        const type = this.decorationTypes.get(icon);
        if (type) {
          editor.setDecorations(type, options);
        }
      }
      this.shown.set(editor, model);
    }
    this.updateLineContext();
  }

  private clear(editor: vscode.TextEditor): void {
    for (const type of this.decorationTypes.values()) {
      editor.setDecorations(type, []);
    }
    this.shown.delete(editor);
  }

  private updateLineContext(): void {
    const editor = vscode.window.activeTextEditor;
    const model = editor ? this.shown.get(editor) : undefined;
    const marks = model && editor?.document.version === model.version ? this.models.marks(model) : [];
    const lines = (wanted: (m: (typeof marks)[number]) => boolean) => marks.filter(wanted).map((m) => m.range.start.line + 1);
    void vscode.commands.executeCommand('setContext', SUPER_LINES_CONTEXT, lines((m) => m.relations.up.length > 0));
    void vscode.commands.executeCommand('setContext', INHERITOR_LINES_CONTEXT,
      lines((m) => m.relations.down.length > 0 || m.pendingDown));
  }
}
