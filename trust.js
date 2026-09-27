/* AmiStampAI - trust level of a verified stamp. */
(function (root) {
  function trustLevel(checks) {
    if (!checks || !checks.length) return null;
    var by = function (k) { return checks.filter(function (c) { return c.kind === k; }); };
    var core = ['key', 'sig', 'hash'].map(function (k) { return by(k)[0]; });
    if (core.some(function (c) { return !c; })) return null;
    if (checks.some(function (c) { return c.state === 'fail'; })) return { level: 'rejected', missing: [] };
    if (core.some(function (c) { return c.state !== 'ok'; })) return { level: 'rejected', missing: [] };
    var coh = by('coherence')[0];
    if (coh && coh.cohLevel === 'necoerent') return { level: 'indeterminate', missing: [] };
    var missing = [];
    var doc = by('doc')[0];
    if (!doc || doc.state !== 'ok') missing.push('doc');
    if (!coh) missing.push('coherence');
    else if (coh.cohLevel !== 'coerent') missing.push('coherence_partial');
    if (!by('anchor').some(function (c) { return c.state === 'ok'; })) missing.push('anchor');
    return { level: missing.length ? 'conditional' : 'certified', missing: missing };
  }
  root.AmiTrust = { trustLevel: trustLevel };
  if (typeof module !== 'undefined' && module.exports) module.exports = { trustLevel: trustLevel };
})(typeof window !== 'undefined' ? window : globalThis);
