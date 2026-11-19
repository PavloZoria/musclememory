import * as vscode from 'vscode';
import { documentSymbols, implementations, subtypes, supertypes } from './lsp';
import { enclosingSymbols, MEMBER_KINDS, TYPE_KINDS } from './symbols';
import { KeyedDebouncer } from './util/keyedDebouncer';
import { type CancellationFlag, type RequestLimiter } from './util/requestLimiter';
import { baseName } from './util/symbolNames';

const MAX_SUPER_DEPTH = 10;

/**
 * How long a "what inherits from this" answer is trusted after a save, or after it came back empty (the server
 * also answers empty while it is still loading projects). With auto-save this caps rechecks at one per 15 s.
 */
export const REVALIDATE_MS = 15_000;

/** A member of a supertype that a member with the same name implements or overrides. */
export interface SuperMember {
  readonly label: string;
  readonly uri: vscode.Uri;
  readonly position: vscode.Position;
  readonly fromInterface: boolean;
}

interface Entry<T> {
  readonly uri: string;
  readonly value: T;
  readonly fetchedAt: number;
}

/**
 * The language server's type-hierarchy answers, cached and shared by "Go to Super", the gutter markers and the
 * CodeLens. A type's supertypes and members are dropped when its own file is saved; subtypes and
 * implementations, which any file can change, are revalidated after saves at most every REVALIDATE_MS.
 */
export class HierarchyService implements vscode.Disposable {
  private readonly supertypesOf = new Map<string, Entry<vscode.TypeHierarchyItem[]>>();
  private readonly membersOf = new Map<string, Entry<Map<string, SuperMember[]>>>();
  private readonly subtypesOf = new Map<string, Entry<vscode.TypeHierarchyItem[]>>();
  private readonly implementationsOf = new Map<string, Entry<vscode.Location[]>>();
  private lastSaveAt = 0;
  private expiredAt = 0;
  private readonly changed = new vscode.EventEmitter<void>();
  private readonly revalidation = new KeyedDebouncer(REVALIDATE_MS);
  private readonly disposables: vscode.Disposable[];

  /** Fires when cached answers may be outdated, so whatever shows them should ask again. */
  readonly onDidChange = this.changed.event;

  constructor(private readonly limiter: RequestLimiter) {
    this.disposables = [
      this.changed,
      vscode.workspace.onDidSaveTextDocument((document) => this.onSave(document.uri)),
    ];
  }

  /** Whether something built from these answers at `builtAt` should be rebuilt. */
  isOutdated(builtAt: number, now = Date.now()): boolean {
    return builtAt < this.expiredAt || (this.lastSaveAt > builtAt && now - builtAt >= REVALIDATE_MS);
  }

  /** Distrusts every cached answer, e.g. once the server may have finished loading projects. */
  expire(): void {
    this.expiredAt = Date.now();
    this.changed.fire();
  }

  async supertypes(item: vscode.TypeHierarchyItem, token?: CancellationFlag): Promise<vscode.TypeHierarchyItem[]> {
    const key = typeKey(item);
    const cached = this.supertypesOf.get(key);
    if (cached && cached.fetchedAt >= this.expiredAt) {
      return cached.value;
    }
    const items = await this.limiter.run(() => supertypes(item), token) ?? [];
    if (items.length > 0) {
      this.supertypesOf.set(key, entry(item.uri, items));
    }
    return items;
  }

  subtypes(item: vscode.TypeHierarchyItem, token?: CancellationFlag): Promise<vscode.TypeHierarchyItem[]> {
    return this.revalidated(this.subtypesOf, typeKey(item), item.uri, () => subtypes(item), token);
  }

  /** Implementations/overrides of a member of `item`, declared at `position` in the item's file. */
  implementations(item: vscode.TypeHierarchyItem, memberName: string, position: vscode.Position,
    token?: CancellationFlag): Promise<vscode.Location[]> {
    return this.revalidated(this.implementationsOf, `${typeKey(item)}.${memberName}`, item.uri,
      () => implementations(item.uri, position), token);
  }

  /** Member name -> the members it implements or overrides, from the nearest supertypes that declare it. */
  async superMemberIndex(supers: readonly vscode.TypeHierarchyItem[], token?: CancellationFlag): Promise<Map<string, SuperMember[]>> {
    const index = new Map<string, SuperMember[]>();
    const foundAtDepth = new Map<string, number>();
    const seen = new Set<string>();
    let level = [...supers];
    for (let depth = 0; level.length > 0 && depth < MAX_SUPER_DEPTH && !token?.isCancellationRequested; depth++) {
      const next: vscode.TypeHierarchyItem[] = [];
      for (const sup of level) {
        const key = typeKey(sup);
        if (seen.has(key)) {
          continue;
        }
        seen.add(key);
        for (const [name, members] of await this.declaredMembers(sup, token)) {
          if (!foundAtDepth.has(name)) {
            foundAtDepth.set(name, depth);
            index.set(name, []);
          }
          if (foundAtDepth.get(name) === depth) {
            index.get(name)?.push(...members);
          }
        }
        next.push(...await this.supertypes(sup, token));
      }
      level = next;
    }
    return index;
  }

  dispose(): void {
    this.revalidation.dispose();
    vscode.Disposable.from(...this.disposables).dispose();
  }

  private async revalidated<T extends readonly unknown[]>(cache: Map<string, Entry<T>>, key: string, uri: vscode.Uri,
    fetch: () => Promise<T>, token?: CancellationFlag): Promise<T> {
    const cached = cache.get(key);
    const now = Date.now();
    const trusted = cached !== undefined
      && cached.fetchedAt >= this.expiredAt
      && (now - cached.fetchedAt < REVALIDATE_MS || (this.lastSaveAt <= cached.fetchedAt && cached.value.length > 0));
    if (cached && trusted) {
      return cached.value;
    }
    const value = await this.limiter.run(fetch, token);
    if (value === undefined) {
      return cached?.value ?? ([] as unknown[] as unknown as T);
    }
    cache.set(key, { uri: uri.toString(), value, fetchedAt: now });
    return value;
  }

  private async declaredMembers(item: vscode.TypeHierarchyItem, token?: CancellationFlag): Promise<Map<string, SuperMember[]>> {
    const key = typeKey(item);
    const cached = this.membersOf.get(key);
    if (cached && cached.fetchedAt >= this.expiredAt) {
      return cached.value;
    }
    // Library types without source have no outline; they simply contribute nothing.
    const symbols = await this.limiter.run(() => documentSymbols(item.uri).then(undefined, () => []), token) ?? [];
    const type = enclosingSymbols(symbols, item.selectionRange.start).filter((s) => TYPE_KINDS.has(s.kind)).pop();
    const members = new Map<string, SuperMember[]>();
    for (const child of type?.children.filter((c) => MEMBER_KINDS.has(c.kind)) ?? []) {
      const name = baseName(child.name);
      const list = members.get(name) ?? [];
      list.push({
        label: `${item.name}.${name}`,
        uri: item.uri,
        position: child.selectionRange.start,
        fromInterface: item.kind === vscode.SymbolKind.Interface,
      });
      members.set(name, list);
    }
    if (type) {
      this.membersOf.set(key, entry(item.uri, members));
    }
    return members;
  }

  private onSave(uri: vscode.Uri): void {
    this.lastSaveAt = Date.now();
    const saved = uri.toString();
    for (const cache of [this.supertypesOf, this.membersOf] as Array<Map<string, Entry<unknown>>>) {
      for (const [key, cached] of cache) {
        if (cached.uri === saved) {
          cache.delete(key);
        }
      }
    }
    // Answers other files depend on become due for a recheck once the revalidation window has passed.
    this.revalidation.schedule('save', () => this.changed.fire());
  }
}

function entry<T>(uri: vscode.Uri, value: T): Entry<T> {
  return { uri: uri.toString(), value, fetchedAt: Date.now() };
}

// Keyed by name rather than position, so cached answers survive edits that shift lines.
function typeKey(item: vscode.TypeHierarchyItem): string {
  return `${item.uri.toString()}#${item.name}`;
}
