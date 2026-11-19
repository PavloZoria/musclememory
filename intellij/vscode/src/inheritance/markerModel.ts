/** A place to jump to, in a form that survives being encoded into a command link. */
export interface Target {
  readonly label: string;
  readonly uri: string;
  readonly line: number;
  readonly character: number;
}

/** What one class, interface or member inherits from (up) and what inherits from it (down). */
export interface Relations {
  readonly isType: boolean;
  readonly up: readonly Target[];
  readonly upFromInterface: boolean;
  readonly down: readonly Target[];
  readonly downFromInterface: boolean;
}

export const MARKER_ICONS = [
  'implements',
  'implemented',
  'implements-implemented',
  'overrides',
  'overridden',
  'overrides-overridden',
] as const;

export type MarkerIcon = (typeof MARKER_ICONS)[number];

/** Green icons for interface relations, blue for class relations; ↑, ↓ or both. */
export function markerIcon(relations: Relations): MarkerIcon {
  const up = relations.up.length > 0;
  const down = relations.down.length > 0;
  const fromInterface = (!up || relations.upFromInterface) && (!down || relations.downFromInterface);
  if (up && down) {
    return fromInterface ? 'implements-implemented' : 'overrides-overridden';
  }
  if (up) {
    return fromInterface ? 'implements' : 'overrides';
  }
  return fromInterface ? 'implemented' : 'overridden';
}

/** CodeLens title for the parents, e.g. "$(arrow-up) implements IOrderRepository" ($(…) renders as an icon). */
export function upLensTitle(relations: Relations, maxNames = 2): string {
  const owners = [...new Set(relations.up.map((target) => (relations.isType ? target.label : ownerOf(target.label))))];
  const verb = relations.upFromInterface ? 'implements' : relations.isType ? 'extends' : 'overrides';
  const more = owners.length > maxNames ? ` +${owners.length - maxNames}` : '';
  return `$(arrow-up) ${verb} ${owners.slice(0, maxNames).join(', ')}${more}`;
}

/** CodeLens title for the inheritors, e.g. "$(arrow-down) 2 implementations". */
export function downLensTitle(count: number, isType: boolean, fromInterface: boolean): string {
  const noun = fromInterface ? 'implementation' : isType ? 'inheritor' : 'override';
  return `$(arrow-down) ${count} ${noun}${count === 1 ? '' : 's'}`;
}

// "IOrderRepository.GetOrder" -> "IOrderRepository".
function ownerOf(memberLabel: string): string {
  const dot = memberLabel.lastIndexOf('.');
  return dot > 0 ? memberLabel.slice(0, dot) : memberLabel;
}

/** Hover text listing the targets as links that run `openCommand` with (uri, line, character). */
export function markerHoverMarkdown(relations: Relations, openCommand: string, maxLinks: number): string {
  const parts: string[] = [];
  if (relations.up.length > 0) {
    const verb = relations.upFromInterface ? 'Implements' : relations.isType ? 'Extends' : 'Overrides';
    parts.push(`**↑ ${verb}** ${links(relations.up, openCommand, maxLinks)}`);
  }
  if (relations.down.length > 0) {
    const verb = relations.isType
      ? (relations.downFromInterface ? 'Implemented by' : 'Subclassed by')
      : (relations.downFromInterface ? 'Implemented in' : 'Overridden in');
    parts.push(`**↓ ${verb}** ${links(relations.down, openCommand, maxLinks)}`);
  }
  return parts.join('\n\n');
}

function links(targets: readonly Target[], openCommand: string, maxLinks: number): string {
  const shown = targets.slice(0, maxLinks).map((target) => {
    const args = encodeURIComponent(JSON.stringify([target.uri, target.line, target.character]));
    return `[${target.label.replace(/[[\]\\]/g, '\\$&')}](command:${openCommand}?${args})`;
  });
  const more = targets.length - shown.length;
  return shown.join(' · ') + (more > 0 ? ` · …and ${more} more` : '');
}
