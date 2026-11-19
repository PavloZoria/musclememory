import { strict as assert } from 'node:assert';
import { describe, it, mock } from 'node:test';
import { KeyedDebouncer } from '../util/keyedDebouncer';
import { RequestLimiter } from '../util/requestLimiter';
import { baseName } from '../util/symbolNames';

const tick = () => new Promise((resolve) => setImmediate(resolve));

describe('RequestLimiter', () => {
  it('never runs more tasks at once than allowed, in arrival order', async () => {
    const limiter = new RequestLimiter(2);
    let running = 0;
    let peak = 0;
    const order: number[] = [];
    await Promise.all([1, 2, 3, 4, 5].map((n) => limiter.run(async () => {
      running++;
      peak = Math.max(peak, running);
      order.push(n);
      await tick();
      running--;
    })));
    assert.equal(peak, 2);
    assert.deepEqual(order, [1, 2, 3, 4, 5]);
  });

  it('skips tasks cancelled while waiting and frees the slot after a failure', async () => {
    const limiter = new RequestLimiter(1);
    const token = { isCancellationRequested: false };
    const first = limiter.run(async () => { await tick(); throw new Error('server error'); });
    const skipped = limiter.run(() => Promise.resolve('ran'), token);
    token.isCancellationRequested = true;
    await assert.rejects(first, /server error/);
    assert.equal(await skipped, undefined);
    assert.equal(await limiter.run(() => Promise.resolve('next')), 'next');
  });
});

describe('KeyedDebouncer', () => {
  it('runs only the last call per key', () => {
    mock.timers.enable({ apis: ['setTimeout'] });
    try {
      const debouncer = new KeyedDebouncer(300);
      const runs: string[] = [];
      debouncer.schedule('a', () => runs.push('a1'));
      debouncer.schedule('a', () => runs.push('a2'));
      debouncer.schedule('b', () => runs.push('b'), 100);
      mock.timers.tick(299);
      assert.deepEqual(runs, ['b']);
      mock.timers.tick(1);
      assert.deepEqual(runs, ['b', 'a2']);
      debouncer.dispose();
    } finally {
      mock.timers.reset();
    }
  });
});

describe('baseName', () => {
  it('strips signatures from outline names', () => {
    assert.equal(baseName('GetOrder(string, CancellationToken) : Task<Order>'), 'GetOrder');
    assert.equal(baseName('Repository<T>'), 'Repository');
    assert.equal(baseName('Email : string'), 'Email');
  });
});
