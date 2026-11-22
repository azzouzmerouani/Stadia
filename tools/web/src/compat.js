// Runtime gaps of old WebViews (Android 10 ships Chrome 74; WeakRef and
// FinalizationRegistry arrived in Chrome 84). esbuild lowers syntax, not
// APIs. Must be imported before three.
//
// three only uses these to drop cache entries for geometries/textures that
// were garbage-collected without dispose(). The viewer disposes everything
// it replaces, and three clears those entries on dispose, so a strong
// reference and a no-op registry are safe here.

if (typeof WeakRef === 'undefined') {
  globalThis.WeakRef = class WeakRef {
    constructor(target) {
      this._target = target;
    }

    deref() {
      return this._target;
    }
  };
}

if (typeof FinalizationRegistry === 'undefined') {
  globalThis.FinalizationRegistry = class FinalizationRegistry {
    register() {}

    unregister() {
      return false;
    }
  };
}
