'use strict';
// Supplementary in-document timing. Semantics and two rAF callbacks are not paint.
function installSemanticsObserver() {
  let pending = null, observer = null, timer = null;
  window.__tm230ArmName = name => {
    observer?.disconnect(); clearTimeout(timer);
    pending = {found: false, observedAt: null, twoAnimationCallbacksAt: null};
    const current = pending;
    const matches = () => {
      for (const node of document.querySelectorAll('flt-semantics, flt-semantics-container')) {
        const label = node.getAttribute('aria-label');
        const text = node.textContent;
        if (text === name || (text.startsWith(name) && /^\s/.test(text.slice(name.length))) || label === name ||
            (label?.startsWith(name) && /^\s/.test(label.slice(name.length)))) return true;
      }
      return false;
    };
    const check = () => {
      if (!matches()) return;
      current.found = true; current.observedAt = Date.now();
      observer.disconnect(); clearTimeout(timer);
      requestAnimationFrame(() => requestAnimationFrame(() => {current.twoAnimationCallbacksAt = Date.now();}));
    };
    observer = new MutationObserver(check);
    observer.observe(document.documentElement, {subtree: true, childList: true, characterData: true,
      attributes: true, attributeFilter: ['aria-label']});
    timer = setTimeout(() => observer.disconnect(), 25000);
    check();
  };
  window.__tm230NameSnapshot = () => pending && {...pending};
}
module.exports = {installSemanticsObserver};
