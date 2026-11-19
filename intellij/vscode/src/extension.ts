import * as vscode from 'vscode';
import { CSharpHighlighter } from './features/csharpHighlighter';
import { InheritanceCodeLens } from './features/inheritanceCodeLens';
import { registerGutterMenu } from './features/inheritanceGutterMenu';
import { InheritanceMarkers } from './features/inheritanceMarkers';
import { registerNavigation } from './features/navigation';
import { registerPush } from './features/push';
import { Switcher } from './features/switcher';
import { HierarchyService } from './hierarchy';
import { InheritanceModels } from './inheritance/models';
import { RequestLimiter } from './util/requestLimiter';

// Background language-server requests the extension sends at once; the rest wait, so editing stays responsive.
const MAX_CONCURRENT_REQUESTS = 4;

export function activate(context: vscode.ExtensionContext): void {
  const log = vscode.window.createOutputChannel('Muscle Memory', { log: true });
  const limiter = new RequestLimiter(MAX_CONCURRENT_REQUESTS);
  const hierarchy = new HierarchyService(limiter);
  const inheritance = new InheritanceModels(hierarchy, limiter, log);
  context.subscriptions.push(
    log,
    hierarchy,
    inheritance,
    new Switcher(),
    registerNavigation(hierarchy),
    registerPush(),
    new CSharpHighlighter(limiter, log),
    new InheritanceMarkers(context, inheritance, log),
    new InheritanceCodeLens(inheritance),
    registerGutterMenu(inheritance),
  );
}

export function deactivate(): void {
  // Everything is released through context.subscriptions.
}
