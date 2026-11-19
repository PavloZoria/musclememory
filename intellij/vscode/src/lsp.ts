import * as vscode from 'vscode';

// Typed wrappers over VS Code's built-in commands that ask the active language servers.

export async function documentSymbols(uri: vscode.Uri): Promise<vscode.DocumentSymbol[]> {
  const symbols = await vscode.commands.executeCommand<Array<vscode.DocumentSymbol | vscode.SymbolInformation> | undefined>(
    'vscode.executeDocumentSymbolProvider', uri);
  return (symbols ?? []).filter((symbol): symbol is vscode.DocumentSymbol => 'selectionRange' in symbol);
}

export async function prepareTypeHierarchy(uri: vscode.Uri, position: vscode.Position): Promise<vscode.TypeHierarchyItem | undefined> {
  const items = await vscode.commands.executeCommand<vscode.TypeHierarchyItem[] | undefined>('vscode.prepareTypeHierarchy', uri, position);
  return items?.[0];
}

export async function supertypes(item: vscode.TypeHierarchyItem): Promise<vscode.TypeHierarchyItem[]> {
  return (await vscode.commands.executeCommand<vscode.TypeHierarchyItem[] | undefined>('vscode.provideSupertypes', item)) ?? [];
}

export async function subtypes(item: vscode.TypeHierarchyItem): Promise<vscode.TypeHierarchyItem[]> {
  return (await vscode.commands.executeCommand<vscode.TypeHierarchyItem[] | undefined>('vscode.provideSubtypes', item)) ?? [];
}

export async function implementations(uri: vscode.Uri, position: vscode.Position): Promise<vscode.Location[]> {
  const locations = await vscode.commands.executeCommand<Array<vscode.Location | vscode.LocationLink> | undefined>(
    'vscode.executeImplementationProvider', uri, position);
  return (locations ?? []).map((location) => 'targetUri' in location
    ? new vscode.Location(location.targetUri, location.targetSelectionRange ?? location.targetRange)
    : location);
}

export async function hoverText(uri: vscode.Uri, position: vscode.Position): Promise<string> {
  const hovers = await vscode.commands.executeCommand<vscode.Hover[] | undefined>('vscode.executeHoverProvider', uri, position);
  return (hovers ?? [])
    .flatMap((hover) => hover.contents)
    .map((content) => (typeof content === 'string' ? content : content.value))
    .join('\n');
}
