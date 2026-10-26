const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('bhobu', {
  send: (cmd) => ipcRenderer.send('cmd', cmd),
  onState: (fn) => ipcRenderer.on('state', (_e, state) => fn(state)),
});
