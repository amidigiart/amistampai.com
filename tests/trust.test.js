// node --test tests/trust.test.js
const test = require('node:test');
const assert = require('node:assert');
const { trustLevel } = require('../trust.js');

const ok = (kind, extra) => Object.assign({ kind, state: 'ok' }, extra || {});
const all = (over) => {
  const base = { key: ok('key'), sig: ok('sig'), hash: ok('hash'), doc: ok('doc'),
                 coherence: ok('coherence', { cohLevel: 'coerent' }), anchor: ok('anchor') };
  Object.assign(base, over || {});
  return Object.values(base).filter(Boolean);
};

test('toate confirmate -> certified', () => {
  assert.deepStrictEqual(trustLevel(all()), { level: 'certified', missing: [] });
});

test('continut modificat (hash invalid) -> rejected', () => {
  assert.strictEqual(trustLevel(all({ hash: { kind: 'hash', state: 'fail' } })).level, 'rejected');
});

test('semnatura falsa -> rejected', () => {
  assert.strictEqual(trustLevel(all({ sig: { kind: 'sig', state: 'fail' } })).level, 'rejected');
});

test('cheie care nu corespunde amprentei -> rejected', () => {
  assert.strictEqual(trustLevel(all({ key: { kind: 'key', state: 'fail' } })).level, 'rejected');
});

test('document furnizat dar diferit -> rejected', () => {
  assert.strictEqual(trustLevel(all({ doc: { kind: 'doc', state: 'fail' } })).level, 'rejected');
});

test('ancora care nu contine stampila -> rejected', () => {
  assert.strictEqual(trustLevel(all({ anchor: { kind: 'anchor', state: 'fail' } })).level, 'rejected');
});

test('atestat de coerenta fals sau al altei stampile -> rejected', () => {
  assert.strictEqual(trustLevel(all({ coherence: { kind: 'coherence', state: 'fail' } })).level, 'rejected');
});

test('sens care nu se potriveste (necoerent) -> indeterminate, chiar cu criptografia perfecta', () => {
  const r = trustLevel(all({ coherence: { kind: 'coherence', state: 'na', cohLevel: 'necoerent' } }));
  assert.strictEqual(r.level, 'indeterminate');
});

test('coerenta partiala -> conditional, cu motivul', () => {
  const r = trustLevel(all({ coherence: { kind: 'coherence', state: 'na', cohLevel: 'partial' } }));
  assert.deepStrictEqual(r, { level: 'conditional', missing: ['coherence_partial'] });
});

test('fara atestat, fara document, fara ancora -> conditional cu toate motivele', () => {
  const r = trustLevel(all({ coherence: null, doc: { kind: 'doc', state: 'na' }, anchor: { kind: 'anchor', state: 'na' } }));
  assert.deepStrictEqual(r, { level: 'conditional', missing: ['doc', 'coherence', 'anchor'] });
});

test('ancora neverificabila acum (retea indisponibila) -> conditional, nu rejected', () => {
  const r = trustLevel(all({ anchor: { kind: 'anchor', state: 'na' } }));
  assert.deepStrictEqual(r, { level: 'conditional', missing: ['anchor'] });
});

test('stampila veche (fara verificari de baza) -> fara nivel', () => {
  assert.strictEqual(trustLevel([{ state: 'na', text: 'legacy' }]), null);
  assert.strictEqual(trustLevel([]), null);
});
