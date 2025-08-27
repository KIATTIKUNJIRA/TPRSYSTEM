
// web/js/ui.helpers.js
export function toast(msg, type='info') {
  const el = document.createElement('div');
  el.style.cssText = 'position:fixed;right:12px;top:12px;padding:10px 14px;border-radius:8px;color:#fff;z-index:9999;';
  el.style.background = type==='danger' ? '#dc3545' : (type==='success' ? '#198754' : '#0d6efd');
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(()=>el.remove(), 2500);
}
