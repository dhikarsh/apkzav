const params = new URLSearchParams(location.search);
const url = params.get('url');
if (url && url.startsWith('https://')) document.getElementById('retry').href = url;
document.getElementById('desc').textContent = params.get('desc') || '';
