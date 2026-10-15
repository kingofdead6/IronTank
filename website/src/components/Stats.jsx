import { useCountUp, useInView } from '../hooks';

const stats = [
  { value: 876, suffix: '+', label: 'Exercises with photos' },
  { value: 7, suffix: '', label: 'Strength rank tiers' },
  { value: 4, suffix: '', label: 'Proven programs built in' },
  { value: 100, suffix: '%', label: 'Offline-safe logging' },
];

function Stat({ value, suffix, label, start, delay }) {
  const n = useCountUp(value, start);
  return (
    <div
      className={`text-center transition-all duration-700 ${start ? 'translate-y-0 opacity-100' : 'translate-y-6 opacity-0'}`}
      style={{ transitionDelay: `${delay}ms` }}
    >
      <p className="font-display text-5xl font-bold md:text-6xl">
        <span className="text-brand">{n}</span>
        {suffix}
      </p>
      <p className="mt-2 text-sm text-muted md:text-base">{label}</p>
    </div>
  );
}

export default function Stats() {
  const [ref, inView] = useInView({ threshold: 0.4 });
  return (
    <section ref={ref} className="relative border-y border-white/5 bg-ink-2/60 py-16">
      <div className="mx-auto grid max-w-6xl grid-cols-2 gap-10 px-6 md:grid-cols-4">
        {stats.map((s, i) => (
          <Stat key={s.label} {...s} start={inView} delay={i * 120} />
        ))}
      </div>
    </section>
  );
}
