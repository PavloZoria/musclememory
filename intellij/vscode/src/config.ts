import * as vscode from 'vscode';

const THEME_NAMES: ReadonlySet<string> = new Set(['Muscle Memory Dark', 'Muscle Memory Light']);

/** Whether one of the extension's own themes is active (the C# colors are only drawn on top of those). */
export function isThemeActive(): boolean {
  return THEME_NAMES.has(vscode.workspace.getConfiguration('workbench').get<string>('colorTheme') ?? '');
}

/** A setting under "musclememory.", e.g. setting('inheritanceMarkers', true). */
export function setting<T>(key: string, fallback: T): T {
  return vscode.workspace.getConfiguration('musclememory').get<T>(key, fallback);
}

export function hint(message: string): void {
  vscode.window.setStatusBarMessage(message, 4000);
}
