// Usage: node tool/gen_pr_burst.mjs assets/lottie/pr_burst.json
// Generates assets/lottie/pr_burst.json: a celebratory burst built from
// expanding rings, radiating rays and twinkling sparkles in the brand colours.
import fs from 'node:fs';

const FR = 60, OP = 120, W = 512, H = 512, C = [W / 2, H / 2];
const orange = [1, 0.416, 0.075, 1], magenta = [1, 0.18, 0.533, 1], gold = [1, 0.843, 0.369, 1];

const ease = (n) => ({ i: { x: Array(n).fill(0.2), y: Array(n).fill(1) }, o: { x: Array(n).fill(0.3), y: Array(n).fill(0) } });
// Animated property from [[frame, value[]], ...]
const anim = (frames) => ({
  a: 1,
  k: frames.map(([t, s], idx) => (idx < frames.length - 1 ? { t, s, ...ease(s.length) } : { t, s })),
});
const fixed = (v) => ({ a: 0, k: v });

const transform = ({ p = C, s = fixed([100, 100, 100]), o = fixed(100), r = fixed(0) } = {}) => ({
  o, r, p: fixed([...p, 0]), a: fixed([0, 0, 0]), s,
});
const shapeTr = () => ({ ty: 'tr', p: fixed([0, 0]), a: fixed([0, 0]), s: fixed([100, 100]), r: fixed(0), o: fixed(100), sk: fixed(0), sa: fixed(0) });

let ind = 1;
const layer = (nm, shapes, ks, ip, op = OP) => ({ ddd: 0, ind: ind++, ty: 4, nm, sr: 1, ks, ao: 0, shapes, ip, op, st: 0, bm: 0 });

const layers = [];

// Three expanding rings, staggered.
[[0, orange, 14], [8, magenta, 10], [16, gold, 6]].forEach(([delay, color, width], i) => {
  layers.push(
    layer(`ring${i}`, [{
      ty: 'gr', nm: 'ring', it: [
        { ty: 'el', d: 1, s: fixed([200, 200]), p: fixed([0, 0]) },
        { ty: 'st', c: fixed(color), o: fixed(100), w: anim([[delay, [width]], [delay + 60, [1]]]), lc: 2, lj: 2 },
        shapeTr(),
      ],
    }], transform({
      s: anim([[delay, [10, 10, 100]], [delay + 60, [230, 230, 100]]]),
      o: anim([[delay, [100]], [delay + 45, [80]], [delay + 60, [0]]]),
    }), delay, delay + 61),
  );
});

// Twelve rays that shoot outward as the layer scales up.
const rays = [];
for (let i = 0; i < 12; i++) {
  const angle = (i * 30 * Math.PI) / 180;
  rays.push({
    ty: 'gr', nm: `ray${i}`, it: [
      { ty: 'rc', d: 1, s: fixed([10, 46]), p: fixed([0, 0]), r: fixed(5) },
      { ty: 'fl', c: fixed(i % 3 === 0 ? gold : i % 2 === 0 ? orange : magenta), o: fixed(100), r: 1 },
      { ...shapeTr(), p: fixed([Math.sin(angle) * 70, -Math.cos(angle) * 70]), r: fixed(i * 30) },
    ],
  });
}
layers.push(layer('rays', rays, transform({
  s: anim([[4, [30, 30, 100]], [50, [260, 260, 100]]]),
  o: anim([[4, [0]], [10, [100]], [38, [100]], [52, [0]]]),
  r: anim([[4, [0]], [52, [20]]]),
}), 4, 53));

// Sparkles: small diamonds that pop in and twinkle out at scattered spots.
const spots = [[-150, -120], [160, -90], [-120, 150], [140, 140], [0, -190], [-200, 20], [200, 30], [30, 200]];
spots.forEach(([x, y], i) => {
  const start = 18 + i * 6;
  layers.push(layer(`spark${i}`, [{
    ty: 'gr', nm: 'diamond', it: [
      { ty: 'sr', sy: 1, d: 1, pt: fixed(4), p: fixed([0, 0]), r: fixed(0), ir: fixed(4), is: fixed(0), or: fixed(14), os: fixed(0) },
      { ty: 'fl', c: fixed(i % 2 ? gold : [1, 1, 1, 1]), o: fixed(100), r: 1 },
      shapeTr(),
    ],
  }], transform({
    p: [C[0] + x, C[1] + y],
    s: anim([[start, [0, 0, 100]], [start + 12, [120, 120, 100]], [start + 30, [0, 0, 100]]]),
    r: anim([[start, [0]], [start + 30, [90]]]),
  }), start, start + 31));
});

const lottie = { v: '5.7.4', fr: FR, ip: 0, op: OP, w: W, h: H, nm: 'pr_burst', ddd: 0, assets: [], layers };
fs.writeFileSync(process.argv[2], JSON.stringify(lottie));
console.log(`wrote ${layers.length} layers, ${JSON.stringify(lottie).length} bytes`);
