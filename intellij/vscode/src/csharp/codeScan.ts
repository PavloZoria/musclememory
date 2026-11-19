/** A range within one line: columns [start, end). */
export interface Span {
  readonly line: number;
  readonly start: number;
  readonly end: number;
}

/** Every call of one method through one receiver in a file, e.g. all "orderRepository.GetOrder(...)". */
export interface CallSite {
  readonly key: string;
  readonly receiver: string;
  readonly method: string;
  readonly spans: Span[];
}

// "[Route(...)]" at line start, or "[FromBody]" opening a parameter; "[key] = value" indexers are excluded.
const ATTRIBUTE_SECTION = /(^|[(,])(\s*)\[([^[\]]+)\](?!\s*=)/g;
const ATTRIBUTE_NAME = /^(\s*(?:\w+\s*:\s*)?)([A-Z_][\w.]*)\s*(?:[(<]|$)/;
const ASYNC_TYPE = /\b(?:Task|ValueTask|IAsyncEnumerable|IAsyncEnumerator|TaskCompletionSource|ConfiguredTaskAwaitable|ConfiguredValueTaskAwaitable)\b/g;
const CALL_SITE = /\b[A-Z]\w*(?=\s*(?:<[^()]*>\s*)?\()/g;
const NOT_A_CALL_BEFORE = /\bnew\s+$|\[\s*$/;
const RECEIVER_BEFORE = /(\w+)[!?]?\s*\.\s*$/;
const TYPE_DECLARATION = /\b(?:class|interface|struct|record)\s+([A-Za-z_]\w*)/g;
const IDENTIFIER = /[A-Za-z_]\w*/g;

/** The lines with comments and string/char literals blanked out (columns kept), so scans only see code. */
export function maskCode(lines: readonly string[]): string[] {
  const masked: string[] = [];
  let inBlockComment = false;
  for (const text of lines) {
    let code = '';
    let i = 0;
    while (i < text.length) {
      let stop: number;
      if (inBlockComment) {
        const end = text.indexOf('*/', i);
        inBlockComment = end < 0;
        stop = inBlockComment ? text.length : end + 2;
      } else if (text.startsWith('//', i)) {
        stop = text.length;
      } else if (text.startsWith('/*', i)) {
        inBlockComment = true;
        stop = i + 2;
      } else if (text[i] === '"' || text[i] === "'") {
        stop = literalEnd(text, i);
      } else {
        code += text[i];
        i++;
        continue;
      }
      code += ' '.repeat(stop - i);
      i = stop;
    }
    masked.push(code);
  }
  return masked;
}

// End of the string or char literal starting at `start`; verbatim strings (@"...") escape quotes by doubling them.
function literalEnd(text: string, start: number): number {
  const quote = text[start];
  const verbatim = quote === '"' && (text[start - 1] === '@' || (text[start - 1] === '$' && text[start - 2] === '@'));
  for (let i = start + 1; i < text.length; i++) {
    if (verbatim && text[i] === '"' && text[i + 1] === '"') {
      i++;
    } else if (!verbatim && text[i] === '\\') {
      i++;
    } else if (text[i] === quote) {
      return i + 1;
    }
  }
  return text.length;
}

/** Names of C# attributes. */
export function attributeSpans(masked: readonly string[]): Span[] {
  const spans: Span[] = [];
  masked.forEach((text, line) => {
    for (const match of text.matchAll(ATTRIBUTE_SECTION)) {
      const contentStart = match.index + match[1].length + match[2].length + 1;
      for (const [offset, name] of attributeNames(match[3])) {
        const start = contentStart + offset;
        spans.push({ line, start, end: start + name.length });
      }
    }
  });
  return spans;
}

// "assembly: Foo, Bar(1, typeof(Baz))" -> [offset, name] for Foo and Bar.
function attributeNames(content: string): Array<[number, string]> {
  const names: Array<[number, string]> = [];
  let depth = 0;
  let partStart = 0;
  for (let i = 0; i <= content.length; i++) {
    const ch = content[i];
    if (ch === '(') {
      depth++;
    } else if (ch === ')') {
      depth--;
    } else if (i === content.length || (ch === ',' && depth === 0)) {
      const part = ATTRIBUTE_NAME.exec(content.slice(partStart, i));
      if (part) {
        names.push([partStart + part[1].length, part[2]]);
      }
      partStart = i + 1;
    }
  }
  return names;
}

/** Task, ValueTask, IAsyncEnumerable and the other async type names. */
export function asyncTypeSpans(masked: readonly string[]): Span[] {
  return masked.flatMap((text, line) => [...text.matchAll(ASYNC_TYPE)]
    .map((match) => ({ line, start: match.index, end: match.index + match[0].length })));
}

/** Calls of PascalCase methods grouped by "receiver.Method", leaving out declarations and constructor calls. */
export function callSites(masked: readonly string[], isDeclaration: (line: number, start: number) => boolean): CallSite[] {
  const sites = new Map<string, { receiver: string; method: string; spans: Span[] }>();
  masked.forEach((text, line) => {
    for (const match of text.matchAll(CALL_SITE)) {
      const before = text.slice(0, match.index);
      if (isDeclaration(line, match.index) || NOT_A_CALL_BEFORE.test(before)) {
        continue;
      }
      const method = match[0];
      const receiver = RECEIVER_BEFORE.exec(before)?.[1] ?? '';
      const key = `${receiver}.${method}`;
      let site = sites.get(key);
      if (!site) {
        site = { receiver, method, spans: [] };
        sites.set(key, site);
      }
      site.spans.push({ line, start: match.index, end: match.index + method.length });
    }
  });
  return [...sites].map(([key, site]) => ({ key, ...site }));
}

/** Names of the classes, interfaces, structs and records declared in the code. */
export function declaredTypeNames(masked: readonly string[]): Set<string> {
  return new Set(masked.flatMap((text) => [...text.matchAll(TYPE_DECLARATION)].map((match) => match[1])));
}

export function identifiers(text: string): Set<string> {
  return new Set(text.match(IDENTIFIER));
}
