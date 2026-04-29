document.addEventListener('click', function(e) {
  const link = e.target.closest('a[href]');
  console.log('[wa-ext] click target:', e.target.tagName, e.target.className?.slice?.(0,50), 'link found:', !!link, link?.href?.slice?.(0,80));
  if (!link) return;
  const url = link.href;
  if ((url.startsWith('https://') || url.startsWith('http://')) &&
      !url.includes('web.whatsapp.com')) {
    e.preventDefault();
    e.stopPropagation();
    console.log('[wa-ext] opening external:', url);
    const a = document.createElement('a');
    a.href = 'waopenin:' + url;
    a.style.display = 'none';
    document.documentElement.appendChild(a);
    a.click();
    a.remove();
  }
}, true);

console.log('[wa-ext] content script loaded');
