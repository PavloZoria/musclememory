import * as vscode from 'vscode';
import { hint } from '../config';
import { type SuperMember } from '../hierarchy';
import { type Target } from './markerModel';

/** Opens (uri, line, character); used by hover links and single-target CodeLens. */
export const OPEN_LOCATION_COMMAND = 'musclememory.openLocation';

/** Where a jump starts: the declaration the user clicked on. */
export interface Anchor {
  readonly uri: vscode.Uri;
  readonly position: vscode.Position;
}

export function itemTarget(item: vscode.TypeHierarchyItem): Target {
  return { label: item.name, uri: item.uri.toString(), line: item.selectionRange.start.line, character: item.selectionRange.start.character };
}

export function superMemberTarget(member: SuperMember): Target {
  return { label: member.label, uri: member.uri.toString(), line: member.position.line, character: member.position.character };
}

export function locationTarget(location: vscode.Location): Target {
  const file = location.uri.path.split('/').pop() ?? location.uri.path;
  return {
    label: `${file}:${location.range.start.line + 1}`,
    uri: location.uri.toString(),
    line: location.range.start.line,
    character: location.range.start.character,
  };
}

/** The command a click runs: jump to a single target, or peek the list, like IntelliJ IDEA's popup. */
export function targetsCommand(targets: readonly Target[], anchor: Anchor, title: string): vscode.Command {
  if (targets.length === 1) {
    const [target] = targets;
    return { title, command: OPEN_LOCATION_COMMAND, arguments: [target.uri, target.line, target.character] };
  }
  if (targets.length > 1) {
    return { title, command: 'editor.action.peekLocations', arguments: [anchor.uri, anchor.position, targets.map(toLocation), 'peek'] };
  }
  return { title, command: '' };
}

export async function revealTargets(targets: readonly Target[], anchor: Anchor, what: string): Promise<void> {
  if (targets.length === 0) {
    hint(`No ${what} found`);
    return;
  }
  const { command, arguments: args = [] } = targetsCommand(targets, anchor, what);
  await vscode.commands.executeCommand(command, ...(args as unknown[]));
}

function toLocation(target: Target): vscode.Location {
  return new vscode.Location(vscode.Uri.parse(target.uri), new vscode.Position(target.line, target.character));
}
