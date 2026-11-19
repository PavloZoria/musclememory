import { strict as assert } from 'node:assert';
import { describe, it } from 'node:test';
import { asyncTypeSpans, attributeSpans, callSites, declaredTypeNames, identifiers, maskCode, type Span } from '../csharp/codeScan';

const texts = (lines: readonly string[], spans: readonly Span[]): string[] =>
  spans.map((span) => `${span.line + 1}:${lines[span.line].slice(span.start, span.end)}`);

describe('maskCode', () => {
  it('blanks comments and literals but keeps every column', () => {
    const lines = ['var s = "Task"; // Task.Run', "var c = '\"'; x = @\"C:\\Tasks\\\"; y /* Task */ = 1;"];
    const masked = maskCode(lines);
    assert.deepEqual(masked.map((line) => line.length), lines.map((line) => line.length));
    assert.ok(masked.every((line) => !line.includes('Task')));
    assert.ok(masked[1].includes('y') && masked[1].endsWith('= 1;'));
  });

  it('carries block comments across lines', () => {
    const masked = maskCode(['/* ValueTask', '   still Task */ ValueTask<int> x;']);
    assert.equal(masked[0].trim(), '');
    assert.deepEqual(texts(masked, asyncTypeSpans(masked)), ['2:ValueTask']);
  });
});

describe('attributeSpans', () => {
  it('finds attribute names in sections and parameters, not indexers or comments', () => {
    const lines = maskCode([
      '[HttpGet("api/[controller]/{id}")] // [NotAnAttribute]',
      '[assembly: InternalsVisibleTo("Tests")]',
      '[Required, MaxLength(50)]',
      'public IActionResult Get([FromRoute] string id, [FromQuery] int page)',
      'dict["key"] = value; items[Index] = x;',
      '["Key"] = 1,',
      '[Foo<int>]',
    ]);
    assert.deepEqual(texts(lines, attributeSpans(lines)),
      ['1:HttpGet', '2:InternalsVisibleTo', '3:Required', '3:MaxLength', '4:FromRoute', '4:FromQuery', '7:Foo']);
  });
});

describe('callSites', () => {
  it('groups calls by receiver and skips declarations, constructors and strings', () => {
    const lines = maskCode([
      'public async Task<int> GetSummaryAsync(string id)',
      'var a = store.GetSummaryAsync(id, ct); var b = orderRepository.GetOrder(id);',
      'var c = orderRepository.GetOrder(other); throw new InvalidOperationException($"{Format(x)}");',
      'await Task.WhenAll(a, b); _ = nameof(GetSummaryAsync); var r = currentRange!.Previous<int>();',
    ]);
    const sites = callSites(lines, (line, start) => line === 0 && start === 23);
    assert.deepEqual(sites.map((s) => `${s.key} x${s.spans.length}`),
      ['store.GetSummaryAsync x1', 'orderRepository.GetOrder x2', 'Task.WhenAll x1', 'currentRange.Previous x1']);
  });
});

describe('declaredTypeNames and identifiers', () => {
  it('lists declared types and the words on a line', () => {
    assert.deepEqual([...declaredTypeNames(['public sealed class OrderRepository : IOrderRepository', 'internal record Item(int X);'])],
      ['OrderRepository', 'Item']);
    assert.deepEqual([...identifiers('var x = store.Get(id_2);')], ['var', 'x', 'store', 'Get', 'id_2']);
  });
});
