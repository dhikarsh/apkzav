const $ = (id) => document.getElementById(id);

const commands = { back: 'back', forward: 'forward', reload: 'reload', home: 'home', homeBtn: 'home',
  zoomIn: 'zoomIn', zoomOut: 'zoomOut', zoomReset: 'zoomReset', theme: 'theme', cs: 'cs' };
for (const [id, cmd] of Object.entries(commands)) {
  $(id).addEventListener('click', () => window.bhobu.send(cmd));
}

let wasLoading = false;
window.bhobu.onState((s) => {
  $('back').disabled = !s.canBack;
  $('forward').disabled = !s.canForward;
  $('zoomReset').textContent = `${s.zoom}%`;
  $('theme').classList.toggle('on', s.theme);
  $('theme').textContent = s.theme ? 'Tema Modern' : 'Tema Asli';
  $('title').textContent = s.title || '';
  const bar = $('bar');
  if (s.loading && !wasLoading) {
    bar.className = 'bar';
    requestAnimationFrame(() => { bar.className = 'bar loading'; });
  } else if (!s.loading) {
    bar.className = 'bar done';
  }
  wasLoading = s.loading;
});
