// Small DOM labels pinned to 3D anchors (stand names, block numbers).
import { Vector3 } from 'three';

const v = new Vector3();

export class Labels {
  constructor(root) {
    this.root = root;
    this.items = new Map();
  }

  /** items: [{key, text, pos: Vector3, color?: css, cls?: string}] */
  set(list) {
    const seen = new Set();
    for (const it of list) {
      seen.add(it.key);
      let cur = this.items.get(it.key);
      if (!cur) {
        const el = document.createElement('div');
        const dot = document.createElement('span');
        const txt = document.createElement('span');
        dot.className = 'dot';
        el.append(dot, txt);
        el.style.opacity = '0';
        this.root.appendChild(el);
        cur = { el, dot, txt };
        this.items.set(it.key, cur);
      }
      cur.pos = it.pos;
      if (cur.txt.textContent !== it.text) cur.txt.textContent = it.text;
      cur.el.className = `lbl ${it.cls || ''}`;
      cur.dot.style.display = it.color ? '' : 'none';
      if (it.color) cur.dot.style.background = it.color;
    }
    for (const [key, cur] of this.items) {
      if (!seen.has(key)) {
        cur.el.remove();
        this.items.delete(key);
      }
    }
  }

  update(camera, w, h) {
    for (const cur of this.items.values()) {
      v.copy(cur.pos).project(camera);
      if (v.z > 1 || v.z < -1 || Math.abs(v.x) > 1.05 || Math.abs(v.y) > 1.05) {
        cur.el.style.opacity = '0';
        continue;
      }
      const x = (v.x * 0.5 + 0.5) * w;
      const y = (-v.y * 0.5 + 0.5) * h;
      cur.el.style.transform = `translate3d(${x.toFixed(1)}px, ${y.toFixed(1)}px, 0) translate(-50%, -50%)`;
      cur.el.style.opacity = '1';
    }
  }
}
