import { useMemo } from 'react';

/** Small deterministic PRNG so stars don't jump around between renders. */
function rng(seed) {
  let s = seed;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

/** Twinkling stars scattered over the parent (which must be `relative`). */
export default function Starfield({ count = 90, seed = 7, className = '' }) {
  const stars = useMemo(() => {
    const r = rng(seed);
    return Array.from({ length: count }, () => ({
      left: r() * 100,
      top: r() * 100,
      size: r() < 0.85 ? 1 + r() * 1.5 : 2.5 + r() * 1.5,
      delay: r() * 6,
      duration: 2.5 + r() * 4,
      tint: r() < 0.15 ? '#ffb36b' : r() < 0.25 ? '#ff8fc4' : '#ffffff',
    }));
  }, [count, seed]);

  return (
    <div className={`pointer-events-none absolute inset-0 ${className}`} aria-hidden="true">
      {stars.map((s, i) => (
        <span
          key={i}
          className="absolute rounded-full animate-twinkle"
          style={{
            left: `${s.left}%`,
            top: `${s.top}%`,
            width: s.size,
            height: s.size,
            background: s.tint,
            boxShadow: s.size > 2.5 ? `0 0 8px ${s.tint}` : undefined,
            animationDelay: `${s.delay}s`,
            animationDuration: `${s.duration}s`,
          }}
        />
      ))}
    </div>
  );
}
