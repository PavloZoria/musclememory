import * as vscode from 'vscode';
import { hint } from '../config';

const MAX_PUSH_PREVIEW = 20;

// The parts of the built-in Git extension's API (vscode.git, version 1) this feature uses.
interface GitBranch {
  readonly name?: string;
  readonly upstream?: { readonly remote: string; readonly name: string };
  readonly ahead?: number;
}

interface GitCommit {
  readonly hash: string;
  readonly message: string;
}

interface GitRepository {
  readonly state: { readonly HEAD: GitBranch | undefined };
  log(options?: { readonly maxEntries?: number }): Promise<GitCommit[]>;
}

interface GitApi {
  readonly repositories: GitRepository[];
  getRepository(uri: vscode.Uri): GitRepository | null;
}

interface GitExtension {
  getAPI(version: 1): GitApi;
}

export function registerPush(): vscode.Disposable {
  return vscode.commands.registerCommand('musclememory.push', pushWithPreview);
}

// Cmd+Shift+K: like IntelliJ IDEA's Push dialog, show the outgoing commits and push only after confirmation.
async function pushWithPreview(): Promise<void> {
  const repository = await currentRepository();
  if (!repository) {
    await vscode.commands.executeCommand('workbench.view.scm');
    return;
  }
  const head = repository.state.HEAD;
  if (!head?.name) {
    hint('Nothing to push: not on a branch');
    return;
  }
  if (!head.upstream) {
    const choice = await vscode.window.showWarningMessage(
      `Branch ${head.name} is not on the remote yet.`,
      { modal: true, detail: 'Publish it to create the remote branch and push its commits.' },
      'Publish Branch',
    );
    if (choice) {
      await vscode.commands.executeCommand('git.publish');
    }
    return;
  }

  const count = head.ahead ?? 0;
  if (count === 0) {
    hint('Nothing to push');
    return;
  }
  const commits = await repository.log({ maxEntries: Math.min(count, MAX_PUSH_PREVIEW) });
  const lines = commits.map((commit) => `${commit.hash.slice(0, 8)}  ${commit.message.split('\n')[0]}`);
  if (count > lines.length) {
    lines.push(`…and ${count - lines.length} more`);
  }
  const target = `${head.upstream.remote}/${head.upstream.name}`;
  const choice = await vscode.window.showWarningMessage(
    `Push ${count} commit${count === 1 ? '' : 's'} to ${target}?`,
    { modal: true, detail: lines.join('\n') },
    'Push',
  );
  if (choice === 'Push') {
    await vscode.commands.executeCommand('git.push');
  }
}

async function currentRepository(): Promise<GitRepository | undefined> {
  const git = vscode.extensions.getExtension<GitExtension>('vscode.git');
  if (!git) {
    return undefined;
  }
  try {
    const api = (git.isActive ? git.exports : await git.activate()).getAPI(1);
    const uri = vscode.window.activeTextEditor?.document.uri;
    return (uri && api.getRepository(uri)) || api.repositories[0];
  } catch {
    return undefined;
  }
}
