// Browser-only harness (index.html?debug without a Flutter host): plays the
// Flutter side of the bridge with fake availability so the scene can be
// tuned in a desktop browser. Keys: Esc = back, I = toggle the large
// bottom inset (seat panel at checkout).

export function installDevHarness(model, log) {
  const send = (m) => window.stadia.receive(m);
  const hash = (s) => {
    let h = 2166136261;
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return (h >>> 0) / 4294967296;
  };

  const blockRatio = {};
  for (const b of model.blocks.values()) {
    blockRatio[b.id] = b.id === 'E_101' ? 0 : Math.round((0.04 + 0.9 * hash(b.id)) * 1000) / 1000;
  }
  const standRatio = {};
  for (const st of model.stands.values()) {
    const rs = st.blocks.map((b) => blockRatio[b.id]);
    standRatio[st.id] = Math.round((rs.reduce((a, b) => a + b, 0) / rs.length) * 1000) / 1000;
  }
  const soldSeats = (blockId) => {
    const info = model.blocks.get(blockId).seatInfo;
    const sold = [];
    for (let i = 0; i < info.rows * info.seats; i++) {
      if (hash(`${blockId}:${i}`) > blockRatio[blockId]) sold.push(i);
    }
    return { info, sold };
  };

  let st = { step: 'stand', stand: null, block: null, seat: null };
  let bigInset = false;
  const push = () => send({ type: 'setStep', ...st });
  const say = (text) => log(`${st.step} ${st.stand || ''} ${st.block || ''} ${st.seat || ''}\n${text}`);

  const back = () => {
    if (st.step === 'buy') st = { ...st, step: 'seat', seat: null };
    else if (st.step === 'seat') st = { ...st, step: 'block', block: null };
    else if (st.step === 'block') st = { step: 'stand', stand: null, block: null, seat: null };
    push();
  };

  window.__stadiaDev = (m) => {
    if (m.type === 'ready') {
      send({
        type: 'labels',
        items: { N: 'North Stand', E: 'East Stand', S: 'South Stand', W: 'Tribune Officielle' },
      });
      send({ type: 'availability', level: 'stand', items: standRatio });
      send({ type: 'availability', level: 'block', items: blockRatio });
      push();
    } else if (m.type === 'select') {
      if (m.level === 'stand' && (st.step === 'stand' || st.step === 'block')) {
        st = { step: 'block', stand: m.id, block: null, seat: null };
      } else if (m.level === 'block' && (st.step === 'block' || st.step === 'seat')) {
        if (blockRatio[m.id] === 0) return say('block sold out');
        const { info, sold } = soldSeats(m.id);
        send({ type: 'availability', level: 'seat', block: m.id, rows: info.rows, seats: info.seats, sold });
        st = { ...st, step: 'seat', block: m.id, seat: null };
      } else if (m.level === 'seat' && st.step === 'seat') {
        const i = model.blocks.get(st.block) && soldSeats(st.block).sold;
        const [, r, s] = /_R(\d+)_S(\d+)$/.exec(m.id) || [];
        const idx = (Number(r) - 1) * model.blocks.get(st.block).seatInfo.seats + (Number(s) - 1);
        if (i && i.includes(idx)) return say(`seat ${m.id} taken`);
        st = { ...st, step: 'buy', seat: m.id };
      } else {
        return say(`ignored ${JSON.stringify(m)}`);
      }
      push();
      say(`select ${m.level} ${m.id}`);
    } else {
      say(JSON.stringify(m).slice(0, 160));
    }
  };

  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' || e.key === 'Backspace') back();
    if (e.key === 'i' || e.key === 'I') {
      bigInset = !bigInset;
      send({ type: 'insets', top: 200, bottom: bigInset ? Math.round(window.innerHeight * 0.58) : 230 });
    }
  });
}
