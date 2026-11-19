import { strict as assert } from 'node:assert';
import { describe, it } from 'node:test';
import { downLensTitle, markerHoverMarkdown, markerIcon, type Relations, type Target, upLensTitle } from '../inheritance/markerModel';

const target = (label: string, line = 0): Target => ({ label, uri: `file:///${label}.cs`, line, character: 4 });
const relations = (overrides: Partial<Relations>): Relations => ({
  isType: false, up: [], upFromInterface: true, down: [], downFromInterface: true, ...overrides,
});

describe('markerIcon', () => {
  it('uses green for interface relations and blue for class relations', () => {
    assert.equal(markerIcon(relations({ up: [target('IOrderRepository')] })), 'implements');
    assert.equal(markerIcon(relations({ down: [target('OrderRepository')] })), 'implemented');
    assert.equal(markerIcon(relations({ up: [target('Entity')], upFromInterface: false })), 'overrides');
    assert.equal(markerIcon(relations({ down: [target('Vehicle')], downFromInterface: false })), 'overridden');
    assert.equal(markerIcon(relations({ up: [target('A')], down: [target('B')] })), 'implements-implemented');
    assert.equal(markerIcon(relations({ up: [target('A')], down: [target('B')], downFromInterface: false })), 'overrides-overridden');
  });
});

describe('CodeLens titles', () => {
  it('names the parents by type, deduplicated and capped', () => {
    assert.equal(upLensTitle(relations({ isType: true, up: [target('IOrderRepository')] })), '$(arrow-up) implements IOrderRepository');
    assert.equal(upLensTitle(relations({ isType: true, up: [target('Entity')], upFromInterface: false })), '$(arrow-up) extends Entity');
    assert.equal(upLensTitle(relations({ up: [target('IOrderRepository.GetOrder')] })), '$(arrow-up) implements IOrderRepository');
    assert.equal(upLensTitle(relations({ up: [target('Entity.Validate')], upFromInterface: false })), '$(arrow-up) overrides Entity');
    assert.equal(upLensTitle(relations({ isType: true, up: [target('IA'), target('IB'), target('IC')] })), '$(arrow-up) implements IA, IB +1');
  });

  it('counts the inheritors with the right noun', () => {
    assert.equal(downLensTitle(1, true, true), '$(arrow-down) 1 implementation');
    assert.equal(downLensTitle(3, true, false), '$(arrow-down) 3 inheritors');
    assert.equal(downLensTitle(2, false, false), '$(arrow-down) 2 overrides');
    assert.equal(downLensTitle(0, false, true), '$(arrow-down) 0 implementations');
  });
});

describe('markerHoverMarkdown', () => {
  it('names the relation and links each target to the open command', () => {
    const markdown = markerHoverMarkdown(relations({ isType: true, down: [target('OrderRepository', 46)] }), 'musclememory.openLocation', 10);
    const args = encodeURIComponent(JSON.stringify(['file:///OrderRepository.cs', 46, 4]));
    assert.equal(markdown, `**↓ Implemented by** [OrderRepository](command:musclememory.openLocation?${args})`);
  });

  it('uses class wording, escapes labels and caps the number of links', () => {
    const markdown = markerHoverMarkdown(relations({
      up: [target('Entity[]')], upFromInterface: false,
      down: [target('A'), target('B'), target('C')], downFromInterface: false,
    }), 'open', 2);
    assert.match(markdown, /^\*\*↑ Overrides\*\* \[Entity\\\[\\\]\]/);
    assert.match(markdown, /\*\*↓ Overridden in\*\* \[A\].* · \[B\].* · …and 1 more$/);
  });
});
