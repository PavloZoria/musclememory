import * as vscode from 'vscode';
import { type InheritanceModels } from '../inheritance/models';
import { type Anchor, revealTargets } from '../inheritance/targets';

/** What the gutter's right-click menu (editor/lineNumber/context) passes to its commands. */
interface GutterLine {
  readonly lineNumber: number;
  readonly uri: vscode.Uri;
}

/**
 * Right-clicking a gutter marker (or its line number) offers "Go to Super" and "Show Implementations", the
 * closest VS Code allows to clicking the icon itself.
 */
export function registerGutterMenu(models: InheritanceModels): vscode.Disposable {
  return vscode.Disposable.from(
    vscode.commands.registerCommand('musclememory.gutterGotoSuper', (line?: GutterLine) => revealFromLine(models, line, 'up')),
    vscode.commands.registerCommand('musclememory.gutterShowInheritors', (line?: GutterLine) => revealFromLine(models, line, 'down')),
  );
}

async function revealFromLine(models: InheritanceModels, line: GutterLine | undefined, direction: 'up' | 'down'): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  const document = line
    ? vscode.workspace.textDocuments.find((d) => d.uri.toString() === line.uri.toString())
    : editor?.document;
  const lineIndex = line ? line.lineNumber - 1 : editor?.selection.active.line;
  if (!document || lineIndex === undefined) {
    return;
  }
  const model = await models.get(document);
  const mark = model && models.marks(model).find((m) => m.range.start.line === lineIndex);
  if (!mark) {
    return;
  }
  const anchor: Anchor = { uri: document.uri, position: mark.range.start };
  if (direction === 'up') {
    await revealTargets(mark.relations.up, anchor, 'super type or method');
    return;
  }
  if (mark.member) {
    await models.resolveDown(document, [mark.member]);
  }
  await revealTargets(mark.member ? mark.member.down ?? [] : mark.relations.down, anchor, 'implementations');
}
