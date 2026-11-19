export interface AwaitableInfo {
  readonly awaitable: boolean;
  /** Type declaring the method ("IOrderRepository" in "IOrderRepository.GetOrder"), used to invalidate on save. */
  readonly declaringType: string | undefined;
}

interface CallKey {
  readonly key: string;
  readonly receiver: string;
  readonly method: string;
}

interface Entry {
  readonly receiver: string;
  readonly method: string;
  readonly info: AwaitableInfo;
}

/**
 * Reads the C# server's hover for a call; it marks methods that return an awaitable with "(awaitable)".
 * Returns undefined when the hover is empty, which means the server can't answer yet.
 */
export function parseAwaitableHover(hover: string, method: string): AwaitableInfo | undefined {
  if (hover.trim() === '') {
    return undefined;
  }
  const escaped = method.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const owner = new RegExp(`([A-Za-z_]\\w*)(?:<[^()]*?>)?\\.${escaped}\\b`).exec(hover);
  return { awaitable: hover.includes('(awaitable)'), declaringType: owner?.[1] };
}

/**
 * The server's answers per document and call, kept across saves except where an edit since the previous save
 * could have changed them. Unanswered calls are asked again only after `retryMs`.
 */
export class AwaitableCache {
  private readonly entries = new Map<string, Map<string, Entry>>();
  private readonly unanswered = new Map<string, number>();

  constructor(private readonly retryMs: number) {}

  get(document: string, key: string): AwaitableInfo | undefined {
    return this.entries.get(document)?.get(key)?.info;
  }

  needsAnswer(document: string, key: string, now = Date.now()): boolean {
    if (this.entries.get(document)?.has(key)) {
      return false;
    }
    const lastAsked = this.unanswered.get(unansweredId(document, key));
    return lastAsked === undefined || now - lastAsked >= this.retryMs;
  }

  record(document: string, call: CallKey, info: AwaitableInfo | undefined, now = Date.now()): void {
    const id = unansweredId(document, call.key);
    if (!info) {
      this.unanswered.set(id, now);
      return;
    }
    this.unanswered.delete(id);
    let entries = this.entries.get(document);
    if (!entries) {
      entries = new Map();
      this.entries.set(document, entries);
    }
    entries.set(call.key, { receiver: call.receiver, method: call.method, info });
  }

  /**
   * After saving `document`, drops the answers an edit since its previous save could have changed:
   * calls in it whose receiver or method was on an edited line, and calls anywhere to an edited method of a type
   * declared in it. Returns how many answers were dropped.
   */
  invalidateAfterSave(document: string, editedWords: ReadonlySet<string>, declaredTypes: ReadonlySet<string>): number {
    let dropped = 0;
    for (const [entriesDocument, entries] of this.entries) {
      for (const [key, entry] of entries) {
        const editedHere = entriesDocument === document && (editedWords.has(entry.receiver) || editedWords.has(entry.method));
        const declarationEdited = entry.info.declaringType !== undefined
          && declaredTypes.has(entry.info.declaringType)
          && editedWords.has(entry.method);
        if (editedHere || declarationEdited) {
          entries.delete(key);
          dropped++;
        }
      }
    }
    return dropped;
  }

  forget(document: string): void {
    this.entries.delete(document);
    const prefix = unansweredId(document, '');
    for (const id of this.unanswered.keys()) {
      if (id.startsWith(prefix)) {
        this.unanswered.delete(id);
      }
    }
  }
}

function unansweredId(document: string, key: string): string {
  return `${document}\n${key}`;
}
