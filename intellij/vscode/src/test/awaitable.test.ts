import { strict as assert } from 'node:assert';
import { describe, it } from 'node:test';
import { AwaitableCache, parseAwaitableHover } from '../csharp/awaitable';

const doc = 'file:///ReportService.cs';
const other = 'file:///InvoiceService.cs';
const call = (receiver: string, method: string) => ({ key: `${receiver}.${method}`, receiver, method });

describe('parseAwaitableHover', () => {
  it('reads "(awaitable)" and the declaring type from real C# server hovers', () => {
    assert.deepEqual(
      parseAwaitableHover('```csharp\n(awaitable) Task<Order> IOrderRepository.GetOrder(string id, [CancellationToken ct = default])\n```', 'GetOrder'),
      { awaitable: true, declaringType: 'IOrderRepository' });
    assert.deepEqual(parseAwaitableHover('```csharp\nDateRange DateRange.Previous()\n```', 'Previous'),
      { awaitable: false, declaringType: 'DateRange' });
    assert.deepEqual(parseAwaitableHover('(awaitable) Task Repository<T>.SaveAsync(T item)', 'SaveAsync'),
      { awaitable: true, declaringType: 'Repository' });
  });

  it('treats an empty hover as "no answer yet"', () => {
    assert.equal(parseAwaitableHover('  ', 'GetOrder'), undefined);
  });
});

describe('AwaitableCache', () => {
  it('asks again for unanswered calls only after the retry delay', () => {
    const cache = new AwaitableCache(5000);
    cache.record(doc, call('store', 'GetSummaryAsync'), undefined, 1000);
    assert.equal(cache.needsAnswer(doc, 'store.GetSummaryAsync', 3000), false);
    assert.equal(cache.needsAnswer(doc, 'store.GetSummaryAsync', 6000), true);
    cache.record(doc, call('store', 'GetSummaryAsync'), { awaitable: true, declaringType: 'IStore' }, 6000);
    assert.equal(cache.needsAnswer(doc, 'store.GetSummaryAsync', 99_000), false);
    assert.equal(cache.get(doc, 'store.GetSummaryAsync')?.awaitable, true);
  });

  it('keeps answers a save could not have changed', () => {
    const cache = new AwaitableCache(5000);
    cache.record(doc, call('orderRepository', 'GetOrder'), { awaitable: true, declaringType: 'IOrderRepository' });
    cache.record(doc, call('currentRange', 'Previous'), { awaitable: false, declaringType: 'DateRange' });
    cache.record(other, call('orderRepository', 'GetOrder'), { awaitable: true, declaringType: 'IOrderRepository' });

    // Edited a line mentioning currentRange in this file: only that call is rechecked.
    assert.equal(cache.invalidateAfterSave(doc, new Set(['var', 'currentRange', 'from']), new Set(['ReportService'])), 1);
    assert.equal(cache.get(doc, 'currentRange.Previous'), undefined);
    assert.ok(cache.get(doc, 'orderRepository.GetOrder'));
    assert.ok(cache.get(other, 'orderRepository.GetOrder'));
  });

  it('drops calls everywhere when the method is edited in the type that declares it', () => {
    const cache = new AwaitableCache(5000);
    cache.record(doc, call('orderRepository', 'GetOrder'), { awaitable: true, declaringType: 'IOrderRepository' });
    cache.record(other, call('orderRepository', 'GetOrder'), { awaitable: true, declaringType: 'IOrderRepository' });
    assert.equal(cache.invalidateAfterSave('file:///IOrderRepository.cs', new Set(['Task', 'Order', 'GetOrder']), new Set(['IOrderRepository'])), 2);
  });

  it('forgets a closed document', () => {
    const cache = new AwaitableCache(5000);
    cache.record(doc, call('a', 'B'), { awaitable: true, declaringType: undefined });
    cache.forget(doc);
    assert.equal(cache.needsAnswer(doc, 'a.B'), true);
  });
});
