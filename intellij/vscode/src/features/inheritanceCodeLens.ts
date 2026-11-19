import * as vscode from 'vscode';
import { setting } from '../config';
import { downLensTitle, upLensTitle } from '../inheritance/markerModel';
import { INHERITANCE_LANGUAGES, type InheritanceModels, type MemberEntry } from '../inheritance/models';
import { type Anchor, targetsCommand } from '../inheritance/targets';

/** A "↓ N implementations" lens whose count is looked up only when VS Code shows it. */
class PendingInheritorsLens extends vscode.CodeLens {
  constructor(range: vscode.Range, readonly document: vscode.TextDocument, readonly member: MemberEntry,
    readonly fromInterface: boolean) {
    super(range);
  }
}

/**
 * Clickable inheritance above declarations, like IntelliJ IDEA's Code Vision: "↑ implements IOrderRepository",
 * "↓ 2 implementations". One target jumps straight there; several open a peek list. VS Code resolves lenses
 * only when they come on screen, so implementations are looked up lazily.
 */
export class InheritanceCodeLens implements vscode.CodeLensProvider, vscode.Disposable {
  private readonly changed = new vscode.EventEmitter<void>();
  private readonly disposables: vscode.Disposable[];

  readonly onDidChangeCodeLenses = this.changed.event;

  constructor(private readonly models: InheritanceModels) {
    this.disposables = [
      this.changed,
      models.onDidChange(() => this.changed.fire()),
      vscode.workspace.onDidChangeConfiguration((e) => {
        if (e.affectsConfiguration('musclememory.inheritanceCodeLens')) {
          this.changed.fire();
        }
      }),
      vscode.languages.registerCodeLensProvider([...INHERITANCE_LANGUAGES].map((language) => ({ language })), this),
    ];
  }

  async provideCodeLenses(document: vscode.TextDocument, token: vscode.CancellationToken): Promise<vscode.CodeLens[]> {
    if (!setting('inheritanceCodeLens', true)) {
      return [];
    }
    const model = await this.models.get(document);
    if (!model || token.isCancellationRequested || model.version !== document.version) {
      return [];
    }
    const lenses: vscode.CodeLens[] = [];
    for (const { range, relations, member, pendingDown } of this.models.marks(model)) {
      const anchor: Anchor = { uri: document.uri, position: range.start };
      if (relations.up.length > 0) {
        lenses.push(new vscode.CodeLens(range, targetsCommand(relations.up, anchor, upLensTitle(relations))));
      }
      if (relations.down.length > 0) {
        const title = downLensTitle(relations.down.length, relations.isType, relations.downFromInterface);
        lenses.push(new vscode.CodeLens(range, targetsCommand(relations.down, anchor, title)));
      } else if (pendingDown && member) {
        lenses.push(new PendingInheritorsLens(range, document, member, relations.downFromInterface));
      }
    }
    return lenses;
  }

  async resolveCodeLens(lens: vscode.CodeLens, token: vscode.CancellationToken): Promise<vscode.CodeLens> {
    if (!(lens instanceof PendingInheritorsLens)) {
      return lens;
    }
    await this.models.resolveDown(lens.document, [lens.member], token);
    const down = lens.member.down ?? [];
    lens.command = targetsCommand(down, { uri: lens.document.uri, position: lens.range.start },
      downLensTitle(down.length, false, lens.fromInterface));
    return lens;
  }

  dispose(): void {
    vscode.Disposable.from(...this.disposables).dispose();
  }
}
