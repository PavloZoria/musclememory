import * as vscode from 'vscode';
import { hint } from '../config';
import { type HierarchyService } from '../hierarchy';
import { OPEN_LOCATION_COMMAND } from '../inheritance/targets';
import { documentSymbols, prepareTypeHierarchy } from '../lsp';
import { enclosingSymbols, flatten, MEMBER_KINDS, TYPE_KINDS } from '../symbols';
import { baseName } from '../util/symbolNames';

// Stops for Next/Previous Method, as in IntelliJ IDEA: methods and properties plus the types containing them.
const METHOD_STOP_KINDS: ReadonlySet<vscode.SymbolKind> = new Set([...TYPE_KINDS, ...MEMBER_KINDS, vscode.SymbolKind.Constructor]);

interface JumpTarget {
  readonly label: string;
  readonly uri: vscode.Uri;
  readonly position: vscode.Position;
}

export function registerNavigation(hierarchy: HierarchyService): vscode.Disposable {
  return vscode.Disposable.from(
    vscode.commands.registerCommand('musclememory.selectOpenedFile', () =>
      vscode.commands.executeCommand('workbench.files.action.showActiveFileInExplorer')),
    vscode.commands.registerCommand(OPEN_LOCATION_COMMAND, (uri: string, line: number, character: number) =>
      vscode.window.showTextDocument(vscode.Uri.parse(uri), { selection: new vscode.Range(line, character, line, character) })),
    vscode.commands.registerCommand('musclememory.gotoSuper', () => withActiveEditor((editor) => gotoSuper(editor, hierarchy))),
    vscode.commands.registerCommand('musclememory.nextMethod', () => withActiveEditor((editor) => moveToMethod(editor, 1))),
    vscode.commands.registerCommand('musclememory.previousMethod', () => withActiveEditor((editor) => moveToMethod(editor, -1))),
  );
}

async function withActiveEditor(run: (editor: vscode.TextEditor) => Promise<void>): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  if (editor) {
    await run(editor);
  }
}

// Cmd+U: inside a member, jump to the member it implements/overrides; on a type, jump to its supertype.
async function gotoSuper(editor: vscode.TextEditor, hierarchy: HierarchyService): Promise<void> {
  const { document } = editor;
  const caret = editor.selection.active;
  const path = enclosingSymbols(await documentSymbols(document.uri), caret);
  const typeIndex = path.findLastIndex((symbol) => TYPE_KINDS.has(symbol.kind));
  const type = typeIndex >= 0 ? path[typeIndex] : undefined;
  const member = type ? path[typeIndex + 1] : undefined;

  const item = await prepareTypeHierarchy(document.uri, type ? type.selectionRange.start : caret);
  if (!item) {
    hint('No super type found: the language server does not provide a type hierarchy here');
    return;
  }
  const supers = await hierarchy.supertypes(item);
  if (member) {
    const matches = (await hierarchy.superMemberIndex(supers)).get(baseName(member.name)) ?? [];
    await jump(matches, 'super method');
  } else {
    await jump(supers.map((s) => ({ label: s.name, uri: s.uri, position: s.selectionRange.start })), 'super type');
  }
}

async function moveToMethod(editor: vscode.TextEditor, direction: 1 | -1): Promise<void> {
  const caret = editor.selection.active;
  const stops = flatten(await documentSymbols(editor.document.uri))
    .filter((symbol) => METHOD_STOP_KINDS.has(symbol.kind))
    .map((symbol) => symbol.selectionRange.start)
    .sort((a, b) => a.compareTo(b));
  const target = direction > 0
    ? stops.find((position) => position.line > caret.line)
    : stops.filter((position) => position.line < caret.line).pop();
  if (!target) {
    return;
  }
  editor.selection = new vscode.Selection(target, target);
  editor.revealRange(new vscode.Range(target, target), vscode.TextEditorRevealType.InCenterIfOutsideViewport);
}

async function jump(targets: readonly JumpTarget[], what: string): Promise<void> {
  if (targets.length === 0) {
    hint(`No ${what} found`);
    return;
  }
  const target = targets.length === 1
    ? targets[0]
    : (await vscode.window.showQuickPick(
        targets.map((t) => ({ label: t.label, description: vscode.workspace.asRelativePath(t.uri), target: t })),
        { placeHolder: `Choose ${what}` },
      ))?.target;
  if (target) {
    await vscode.window.showTextDocument(target.uri, { selection: new vscode.Range(target.position, target.position) });
  }
}
