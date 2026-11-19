import * as vscode from 'vscode';
import { hint } from '../config';

const SWITCHER_CONTEXT = 'musclememory.switcherVisible';
const MAX_RECENT_FILES = 200;
const NAVIGATE_NEXT = 'workbench.action.quickOpenNavigateNextInEditorPicker';
const NAVIGATE_PREVIOUS = 'workbench.action.quickOpenNavigatePreviousInEditorPicker';

type FileTab = vscode.Tab & { readonly input: vscode.TabInputText };

interface FileItem extends vscode.QuickPickItem {
  readonly uri: vscode.Uri;
  readonly viewColumn: vscode.ViewColumn;
  // Gives the item its file icon; VS Code supports it, but it is newer than the @types/vscode this targets.
  readonly resourceUri: vscode.Uri;
}

/** Ctrl+Tab: IntelliJ IDEA's Switcher limited to open files (no settings, output or panels), across all splits. */
export class Switcher implements vscode.Disposable {
  // File URIs, most recently used first.
  private readonly recent: string[] = [];
  private readonly lastViewColumn = new Map<string, vscode.ViewColumn>();
  private readonly disposables: vscode.Disposable[];

  constructor() {
    for (const tab of fileTabs()) {
      this.remember(tab.input.uri, tab.group.viewColumn, false);
    }
    if (vscode.window.activeTextEditor) {
      this.rememberEditor(vscode.window.activeTextEditor);
    }
    this.disposables = [
      vscode.window.onDidChangeActiveTextEditor((editor) => editor && this.rememberEditor(editor)),
      vscode.commands.registerCommand('musclememory.switcher', () => this.show(1)),
      vscode.commands.registerCommand('musclememory.switcherBack', () => this.show(-1)),
    ];
  }

  dispose(): void {
    vscode.Disposable.from(...this.disposables).dispose();
  }

  private async show(direction: 1 | -1): Promise<void> {
    const open = new Map<string, FileTab>();
    for (const tab of fileTabs()) {
      const key = tab.input.uri.toString();
      if (!open.has(key) || tab.group.viewColumn === this.lastViewColumn.get(key)) {
        open.set(key, tab);
      }
    }
    const keys = [
      ...this.recent.filter((key) => open.has(key)),
      ...[...open.keys()].filter((key) => !this.recent.includes(key)),
    ];
    if (keys.length === 0) {
      hint('No open files');
      return;
    }

    const picker = vscode.window.createQuickPick<FileItem>();
    picker.placeholder = 'Open files';
    picker.matchOnDescription = true;
    picker.items = keys.flatMap((key) => {
      const tab = open.get(key);
      if (!tab) {
        return [];
      }
      const { uri } = tab.input;
      return [{
        label: tab.label,
        description: vscode.workspace.asRelativePath(vscode.Uri.joinPath(uri, '..')),
        iconPath: vscode.ThemeIcon.File,
        resourceUri: uri,
        uri,
        viewColumn: tab.group.viewColumn,
      }];
    });
    picker.onDidAccept(() => {
      const [item] = picker.selectedItems.length > 0 ? picker.selectedItems : picker.activeItems;
      picker.hide();
      if (item) {
        void vscode.window.showTextDocument(item.uri, { viewColumn: item.viewColumn });
      }
    });
    picker.onDidHide(() => {
      void vscode.commands.executeCommand('setContext', SWITCHER_CONTEXT, false);
      picker.dispose();
    });

    await vscode.commands.executeCommand('setContext', SWITCHER_CONTEXT, true);
    picker.show();
    // Moving through VS Code's own navigate command arms "open on Ctrl release", like IntelliJ IDEA's Switcher.
    await vscode.commands.executeCommand(direction > 0 ? NAVIGATE_NEXT : NAVIGATE_PREVIOUS);
  }

  private rememberEditor(editor: vscode.TextEditor): void {
    if (editor.document.uri.scheme === 'file') {
      this.remember(editor.document.uri, editor.viewColumn, true);
    }
  }

  private remember(uri: vscode.Uri, viewColumn: vscode.ViewColumn | undefined, mostRecent: boolean): void {
    const key = uri.toString();
    const index = this.recent.indexOf(key);
    if (index >= 0) {
      if (!mostRecent) {
        return;
      }
      this.recent.splice(index, 1);
    }
    if (mostRecent) {
      this.recent.unshift(key);
    } else {
      this.recent.push(key);
    }
    this.recent.length = Math.min(this.recent.length, MAX_RECENT_FILES);
    if (viewColumn) {
      this.lastViewColumn.set(key, viewColumn);
    }
  }
}

function fileTabs(): FileTab[] {
  return vscode.window.tabGroups.all
    .flatMap((group) => group.tabs)
    .filter((tab): tab is FileTab => tab.input instanceof vscode.TabInputText && tab.input.uri.scheme === 'file');
}
