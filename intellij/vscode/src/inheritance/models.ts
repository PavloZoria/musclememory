import * as vscode from 'vscode';
import { type HierarchyService, REVALIDATE_MS, type SuperMember } from '../hierarchy';
import { documentSymbols, prepareTypeHierarchy } from '../lsp';
import { flatten, MEMBER_KINDS, TYPE_KINDS } from '../symbols';
import { type CancellationFlag, type RequestLimiter } from '../util/requestLimiter';
import { baseName } from '../util/symbolNames';
import { type Relations, type Target } from './markerModel';
import { itemTarget, locationTarget, superMemberTarget } from './targets';

export const INHERITANCE_LANGUAGES: ReadonlySet<string> = new Set(['csharp', 'kotlin', 'java']);

const OVERRIDABLE = /\b(?:virtual|abstract|override|open)\b/;
const STATIC = /\bstatic\b/;
// The server answers with empty hierarchies while it is still loading projects; recheck everything a few times.
const STARTUP_RECHECKS_MS = [20_000, 60_000, 120_000];

export interface MemberEntry {
  readonly symbol: vscode.DocumentSymbol;
  readonly name: string;
  readonly typeItem: vscode.TypeHierarchyItem;
  readonly up: readonly SuperMember[];
  readonly canBeOverridden: boolean;
  /** Implementations/overrides; undefined until asked for, which happens once the member is on screen. */
  down: Target[] | undefined;
}

export interface TypeEntry {
  readonly symbol: vscode.DocumentSymbol;
  readonly isInterface: boolean;
  readonly supers: readonly vscode.TypeHierarchyItem[];
  readonly subs: readonly vscode.TypeHierarchyItem[];
  readonly members: MemberEntry[];
}

export interface DocumentModel {
  readonly version: number;
  readonly builtAt: number;
  readonly types: TypeEntry[];
}

/** One declaration with inheritance, as shown by the markers and the CodeLens. */
export interface Mark {
  readonly range: vscode.Range;
  readonly relations: Relations;
  /** The member, when the declaration is one; its implementations may still be unknown. */
  readonly member: MemberEntry | undefined;
  readonly pendingDown: boolean;
}

/**
 * What every class, interface and member in a file inherits from and what inherits from it, built once per
 * document version from the shared HierarchyService and reused by the gutter markers, the gutter menu and the
 * CodeLens.
 */
export class InheritanceModels implements vscode.Disposable {
  private readonly models = new Map<string, DocumentModel>();
  private readonly builds = new Map<string, { readonly version: number; readonly promise: Promise<DocumentModel | undefined>;
    readonly cancellation: vscode.CancellationTokenSource }>();
  private readonly changed = new vscode.EventEmitter<void>();
  private readonly disposables: vscode.Disposable[];

  /** Fires when models may be outdated, so markers and CodeLens should ask again. */
  readonly onDidChange = this.changed.event;

  constructor(private readonly hierarchy: HierarchyService, private readonly limiter: RequestLimiter,
    private readonly log: vscode.LogOutputChannel) {
    this.disposables = [
      this.changed,
      hierarchy.onDidChange(() => this.changed.fire()),
      // A save changes the saved file's own declarations; other files follow after the revalidation window.
      vscode.workspace.onDidSaveTextDocument((document) => {
        this.models.delete(document.uri.toString());
        this.changed.fire();
      }),
      vscode.workspace.onDidCloseTextDocument((document) => this.models.delete(document.uri.toString())),
      vscode.languages.onDidChangeDiagnostics((e) => {
        if (e.uris.some((uri) => this.isEmptyAndDue(uri))) {
          this.changed.fire();
        }
      }),
      vscode.commands.registerCommand('musclememory.refreshInheritanceMarkers', () => {
        this.models.clear();
        this.hierarchy.expire();
      }),
      ...STARTUP_RECHECKS_MS.map((delay) => {
        const timer = setTimeout(() => this.hierarchy.expire(), delay);
        return new vscode.Disposable(() => clearTimeout(timer));
      }),
    ];
  }

  /** The model for the document's current version, building it if needed. */
  async get(document: vscode.TextDocument): Promise<DocumentModel | undefined> {
    const key = document.uri.toString();
    const model = this.models.get(key);
    if (model && model.version === document.version && !this.isOutdated(model)) {
      return model;
    }
    const running = this.builds.get(key);
    if (running?.version === document.version) {
      return running.promise;
    }
    running?.cancellation.cancel();
    const cancellation = new vscode.CancellationTokenSource();
    const promise = this.build(document, cancellation.token).finally(() => {
      if (this.builds.get(key)?.promise === promise) {
        this.builds.delete(key);
      }
      cancellation.dispose();
    });
    this.builds.set(key, { version: document.version, promise, cancellation });
    return promise;
  }

  /** Looks up implementations of the given members that haven't been asked for. Returns whether any were. */
  async resolveDown(document: vscode.TextDocument, members: readonly MemberEntry[], token?: CancellationFlag): Promise<boolean> {
    const pending = members.filter((member) => member.canBeOverridden && member.down === undefined);
    if (pending.length === 0) {
      return false;
    }
    await Promise.all(pending.map(async (member) => {
      const start = member.symbol.selectionRange.start;
      const locations = await this.hierarchy.implementations(member.typeItem, member.name, start, token).then(undefined, () => []);
      if (token?.isCancellationRequested) {
        return;
      }
      member.down = locations
        .filter((l) => l.uri.toString() !== document.uri.toString() || l.range.start.line !== start.line)
        .map(locationTarget);
    }));
    return true;
  }

  marks(model: DocumentModel): Mark[] {
    const marks: Mark[] = [];
    for (const type of model.types) {
      marks.push({
        range: type.symbol.selectionRange,
        member: undefined,
        pendingDown: false,
        relations: {
          isType: true,
          up: type.supers.map(itemTarget),
          upFromInterface: type.supers.every((s) => s.kind === vscode.SymbolKind.Interface),
          down: type.subs.map(itemTarget),
          downFromInterface: type.isInterface,
        },
      });
      for (const member of type.members) {
        marks.push({
          range: member.symbol.selectionRange,
          member,
          pendingDown: member.canBeOverridden && member.down === undefined,
          relations: {
            isType: false,
            up: member.up.map(superMemberTarget),
            upFromInterface: member.up.every((m) => m.fromInterface),
            down: member.down ?? [],
            downFromInterface: type.isInterface,
          },
        });
      }
    }
    return marks.filter((m) => m.relations.up.length > 0 || m.relations.down.length > 0 || m.pendingDown);
  }

  dispose(): void {
    for (const build of this.builds.values()) {
      build.cancellation.cancel();
    }
    vscode.Disposable.from(...this.disposables).dispose();
  }

  private isOutdated(model: DocumentModel): boolean {
    const emptyAndDue = model.types.every((t) => t.supers.length === 0 && t.subs.length === 0)
      && Date.now() - model.builtAt >= REVALIDATE_MS;
    return emptyAndDue || this.hierarchy.isOutdated(model.builtAt);
  }

  private isEmptyAndDue(uri: vscode.Uri): boolean {
    const model = this.models.get(uri.toString());
    return model !== undefined && this.marks(model).length === 0 && Date.now() - model.builtAt >= REVALIDATE_MS;
  }

  private async build(document: vscode.TextDocument, token: vscode.CancellationToken): Promise<DocumentModel | undefined> {
    const builtAt = Date.now();
    const version = document.version;
    const symbols = await this.limiter.run(() => documentSymbols(document.uri), token);
    if (symbols === undefined) {
      return undefined;
    }
    const types: TypeEntry[] = [];
    for (const symbol of flatten(symbols).filter((s) => TYPE_KINDS.has(s.kind))) {
      const item = await this.limiter.run(() => prepareTypeHierarchy(document.uri, symbol.selectionRange.start), token);
      if (token.isCancellationRequested) {
        return undefined;
      }
      if (!item) {
        continue;
      }
      const isInterface = symbol.kind === vscode.SymbolKind.Interface;
      const [supers, subs] = await Promise.all([this.hierarchy.supertypes(item, token), this.hierarchy.subtypes(item, token)]);
      const superMembers = await this.hierarchy.superMemberIndex(supers, token);
      const members = symbol.children.filter((child) => MEMBER_KINDS.has(child.kind)).map((child): MemberEntry => {
        const declaration = document.lineAt(child.selectionRange.start.line).text;
        const name = baseName(child.name);
        return {
          symbol: child,
          name,
          typeItem: item,
          up: STATIC.test(declaration) ? [] : superMembers.get(name) ?? [],
          canBeOverridden: subs.length > 0 && (isInterface || OVERRIDABLE.test(declaration) || document.languageId === 'java'),
          down: undefined,
        };
      });
      types.push({ symbol, isInterface, supers, subs, members });
    }
    if (token.isCancellationRequested || document.version !== version) {
      return undefined;
    }
    const model: DocumentModel = { version, builtAt, types };
    this.models.set(document.uri.toString(), model);
    this.log.debug(`${vscode.workspace.asRelativePath(document.uri)}: inheritance of ${types.length} type(s) in ${Date.now() - builtAt} ms`);
    return model;
  }
}
