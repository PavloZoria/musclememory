/** Cancellation as the limiter sees it; `vscode.CancellationToken` has this shape. */
export interface CancellationFlag {
  readonly isCancellationRequested: boolean;
}

/**
 * Runs at most `maxConcurrent` tasks at once, in arrival order, so background work never floods a language
 * server and completions and diagnostics stay responsive. Tasks cancelled while waiting are skipped.
 */
export class RequestLimiter {
  private active = 0;
  private readonly waiting: Array<() => void> = [];

  constructor(private readonly maxConcurrent: number) {}

  /** Resolves to the task's result, or `undefined` when the token was cancelled before the task could start. */
  async run<T>(task: () => PromiseLike<T>, token?: CancellationFlag): Promise<T | undefined> {
    await this.acquire();
    try {
      return token?.isCancellationRequested ? undefined : await task();
    } finally {
      this.release();
    }
  }

  private acquire(): Promise<void> {
    if (this.active < this.maxConcurrent) {
      this.active++;
      return Promise.resolve();
    }
    return new Promise((resolve) => this.waiting.push(resolve));
  }

  private release(): void {
    const next = this.waiting.shift();
    if (next) {
      next(); // the slot passes straight to the next waiting task
    } else {
      this.active--;
    }
  }
}
