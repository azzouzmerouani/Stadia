// JS side of the Flutter bridge.
//
// Flutter -> JS: window.stadia.receive({type, ...})   (object or JSON string)
// JS -> Flutter: StadiaBridge.postMessage(JSON)       (webview_flutter channel)
//
// Messages that arrive before the model is ready are queued.

const listeners = [];
const queue = [];
let ready = false;

export function hasHost() {
  return !!(window.StadiaBridge && typeof window.StadiaBridge.postMessage === 'function');
}

export function post(message) {
  const json = JSON.stringify(message);
  if (hasHost()) {
    window.StadiaBridge.postMessage(json);
  } else if (typeof window.__stadiaDev === 'function') {
    window.__stadiaDev(message);
  } else {
    console.log('[stadia ->]', json);
  }
}

export function onMessage(fn) {
  listeners.push(fn);
}

export function setReady() {
  ready = true;
  for (const msg of queue.splice(0)) dispatch(msg);
}

function dispatch(msg) {
  for (const fn of listeners) {
    try {
      fn(msg);
    } catch (err) {
      console.error(err);
      post({ type: 'error', message: String((err && err.message) || err) });
    }
  }
}

window.stadia = {
  receive(raw) {
    let msg = raw;
    if (typeof raw === 'string') {
      try {
        msg = JSON.parse(raw);
      } catch {
        return;
      }
    }
    if (!msg || typeof msg.type !== 'string') return;
    if (ready) dispatch(msg);
    else queue.push(msg);
  },
};
