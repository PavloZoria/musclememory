/** Trailing debounce per key: of several calls for one key within the delay, only the last one runs. */
export class KeyedDebouncer {
  private readonly timers = new Map<string, ReturnType<typeof setTimeout>>();

  constructor(private readonly defaultDelayMs: number) {}

  schedule(key: string, run: () => void, delayMs = this.defaultDelayMs): void {
    clearTimeout(this.timers.get(key));
    this.timers.set(key, setTimeout(() => {
      this.timers.delete(key);
      run();
    }, Math.max(0, delayMs)));
  }

  dispose(): void {
    for (const timer of this.timers.values()) {
      clearTimeout(timer);
    }
    this.timers.clear();
  }
}
