document.addEventListener('click', function(e) {
  const link = e.target.closest('a[href]');
  if (!link) return;
  const url = link.href;
  if ((url.startsWith('https://') || url.startsWith('http://')) &&
      new URL(url).hostname !== window.location.hostname) {
    e.preventDefault();
    e.stopPropagation();
    const a = document.createElement('a');
    a.href = 'waopenin:' + url;
    a.style.display = 'none';
    document.documentElement.appendChild(a);
    a.click();
    a.remove();
  }
}, true);
