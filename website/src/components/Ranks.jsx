import { useEffect, useState } from 'react';
import { useInView } from '../hooks';
import Phone from './Phone';
import Reveal from './Reveal';

// Same tier colours as the app (mobile/lib/core/theme/app_colors.dart).
const tiers = [
  { name: 'Bronze', from: '#e09a5f', to: '#8a4b22' },
  { name: 'Silver', from: '#e3e8ef', to: '#8d97a6' },
  { name: 'Gold', from: '#ffd75e', to: '#c98a0b' },
  { name: 'Platinum', from: '#7ff5e1', to: '#14a38b' },
  { name: 'Diamond', from: '#8cc8ff', to: '#3a63f0' },
  { name: 'Elite', from: '#c9a6ff', to: '#7438e8' },
  { name: 'Legend', from: '#ff6b6b', to: '#ffc23d' },
];
const numerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];

function HexBadge({ tier, index, lit, highlighted }) {
  return (
    <div className="flex flex-col items-center gap-3">
      <div
        className={`relative transition-all duration-700 ease-out ${lit ? 'scale-100 opacity-100' : 'scale-50 opacity-0'} ${highlighted ? 'scale-125' : ''}`}
        style={{ transitionDelay: `${index * 120}ms` }}
      >
        {highlighted && (
          <div className="hex absolute -inset-3 animate-spin-slow opacity-70 blur-md" style={{ background: `conic-gradient(${tier.from}, ${tier.to}, ${tier.from})` }} />
        )}
        <div
          className="hex relative flex h-20 w-[4.5rem] items-center justify-center md:h-24 md:w-[5.4rem]"
          style={{ background: `linear-gradient(135deg, ${tier.from}, ${tier.to})` }}
        >
          <div className="hex absolute inset-[6px] bg-linear-to-br from-white/25 to-transparent" />
          <span className="font-display relative text-xl font-bold text-white drop-shadow md:text-2xl">{numerals[index]}</span>
        </div>
      </div>
      <span
        className={`text-sm font-semibold transition-all duration-500 ${highlighted ? 'scale-110' : ''}`}
        style={{ color: highlighted ? tier.from : 'rgb(255 255 255 / 0.6)' }}
      >
        {tier.name}
      </span>
    </div>
  );
}

export default function Ranks() {
  const [ref, inView] = useInView({ threshold: 0.3 });
  const [highlight, setHighlight] = useState(-1);

  // Once visible, the highlight climbs the ladder tier by tier, then repeats.
  useEffect(() => {
    if (!inView) return;
    let i = -1;
    const id = setInterval(() => {
      i = (i + 1) % tiers.length;
      setHighlight(i);
    }, 1100);
    return () => clearInterval(id);
  }, [inView]);

  return (
    <section id="ranks" className="relative scroll-mt-24 overflow-hidden py-28">
      <div className="pointer-events-none absolute left-1/2 top-1/3 h-96 w-[40rem] -translate-x-1/2 rounded-full bg-magenta/10 blur-[120px]" />
      <div className="relative mx-auto grid max-w-6xl items-center gap-16 px-6 lg:grid-cols-[1fr_20rem]">
        <div>
          <Reveal>
            <p className="font-display text-sm font-bold uppercase tracking-[0.3em] text-brand">Strength ranks</p>
            <h2 className="mt-4 text-4xl font-black tracking-tight md:text-6xl">How strong are you, really?</h2>
            <p className="mt-5 max-w-xl text-lg text-white/65">
              IronRank compares your estimated one-rep max to your bodyweight on bench, squat, deadlift, overhead press, rows,
              pull-ups and dips — using standards for men and women. Every rank shows exactly what you need to reach the next one.
            </p>
          </Reveal>
          <div ref={ref} className="mt-14 flex flex-wrap justify-center gap-x-4 gap-y-8 lg:justify-start">
            {tiers.map((t, i) => (
              <HexBadge key={t.name} tier={t} index={i} lit={inView} highlighted={i === highlight} />
            ))}
          </div>
        </div>
        <Reveal delay={200} className="mx-auto w-full max-w-[18rem]">
          <Phone src="./screenshots/ranks.png" alt="IronRank ranks screen" />
        </Reveal>
      </div>
    </section>
  );
}
