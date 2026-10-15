import { DOWNLOAD_URL } from '../config';
import { paths } from '../router';
import Starfield from './Starfield';

const columns = [
  {
    title: 'Product',
    links: [
      { label: 'Features', href: '#features' },
      { label: 'Strength ranks', href: '#ranks' },
      { label: 'Screenshots', href: '#screens' },
      { label: 'How to install', href: '#install' },
    ],
  },
  {
    title: 'Legal',
    links: [
      { label: 'Privacy Policy', href: paths.privacy },
      { label: 'Terms of Use', href: paths.terms },
      { label: 'Health Disclaimer', href: paths.disclaimer },
    ],
  },
  {
    title: 'Resources',
    links: [
      { label: 'Download the app', href: DOWNLOAD_URL || '#install' },
      { label: 'Exercise database', href: 'https://github.com/yuhonas/free-exercise-db', external: true },
    ],
  },
];

/**
 * Planetary footer: a starfield over a giant glowing planet horizon, with
 * moons on tilted orbits and the wordmark rising from the planet.
 */
export default function Footer() {
  return (
    <footer className="relative overflow-hidden bg-ink pt-24">
      <Starfield count={110} seed={42} />

      {/* Links */}
      <div className="relative z-10 mx-auto grid max-w-6xl gap-12 px-6 md:grid-cols-[1.4fr_1fr_1fr_1fr]">
        <div>
          <a href={paths.home} className="group inline-flex items-center gap-3">
            <img src="./icon.png" alt="" className="h-11 w-11 rounded-2xl transition-transform duration-500 group-hover:rotate-12 group-hover:scale-110" />
            <span className="font-display text-xl font-bold tracking-wider">
              IRON<span className="text-brand">RANK</span>
            </span>
          </a>
          <p className="mt-5 max-w-xs leading-relaxed text-white/55">
            Log every rep, smash your PRs and climb from Bronze to Legend. Free, offline-ready, no ads.
          </p>
        </div>
        {columns.map((col) => (
          <nav key={col.title} aria-label={col.title}>
            <h3 className="font-display text-xs font-bold uppercase tracking-[0.25em] text-white/40">{col.title}</h3>
            <ul className="mt-5 space-y-3">
              {col.links.map((l) => (
                <li key={l.label}>
                  <a
                    href={l.href}
                    {...(l.external ? { target: '_blank', rel: 'noreferrer' } : {})}
                    className="group inline-flex items-center gap-2 text-white/70 transition-colors hover:text-white"
                  >
                    <span className="h-1 w-1 rounded-full bg-white/30 transition-all duration-300 group-hover:w-3 group-hover:bg-magenta" />
                    {l.label}
                    {l.external && <span className="text-xs text-white/35">↗</span>}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        ))}
      </div>

      {/* Planet scene */}
      <div className="relative mt-16 h-[26rem] md:h-[30rem]" aria-hidden="true">
        {/* Tilted orbits with travelling moons */}
        <svg className="absolute left-1/2 top-0 h-full w-[140%] max-w-none -translate-x-1/2 md:w-full" viewBox="0 0 1200 480" preserveAspectRatio="xMidYMid slice">
          <defs>
            <linearGradient id="orbit" x1="0" x2="1">
              <stop offset="0" stopColor="#f25c05" stopOpacity="0" />
              <stop offset="0.5" stopColor="#ff2e88" stopOpacity="0.55" />
              <stop offset="1" stopColor="#f25c05" stopOpacity="0" />
            </linearGradient>
            <radialGradient id="moon" cx="0.35" cy="0.35" r="0.65">
              <stop offset="0" stopColor="#fff" />
              <stop offset="0.5" stopColor="#ffb36b" />
              <stop offset="1" stopColor="#ff2e88" />
            </radialGradient>
          </defs>
          <ellipse cx="600" cy="330" rx="560" ry="110" fill="none" stroke="url(#orbit)" strokeWidth="1.2" />
          <ellipse cx="600" cy="330" rx="430" ry="70" fill="none" stroke="url(#orbit)" strokeWidth="1" strokeDasharray="4 8" />
          <circle r="9" fill="url(#moon)">
            <animateMotion dur="26s" repeatCount="indefinite" path="M40,330 a560,110 0 1,0 1120,0 a560,110 0 1,0 -1120,0" />
          </circle>
          <circle r="5" fill="#fff" opacity="0.85">
            <animateMotion dur="17s" repeatCount="indefinite" path="M1030,330 a430,70 0 1,0 -860,0 a430,70 0 1,0 860,0" />
          </circle>
        </svg>

        {/* Wordmark rising from the horizon */}
        <div className="absolute inset-x-0 top-[22%] flex justify-center">
          <span
            className="select-none bg-clip-text font-display text-[22vw] font-bold leading-none tracking-tighter text-transparent md:text-[13rem]"
            style={{ backgroundImage: 'linear-gradient(180deg, rgb(255 255 255 / 0.22) 0%, rgb(255 255 255 / 0.04) 70%, transparent 100%)' }}
          >
            IRONRANK
          </span>
        </div>

        {/* The planet: a huge circle whose top arc forms a glowing horizon */}
        <div className="absolute left-1/2 top-[58%] aspect-square w-[260%] -translate-x-1/2 rounded-full md:w-[170%]">
          {/* Atmosphere glow */}
          <div className="absolute -inset-10 rounded-full bg-[radial-gradient(closest-side,rgb(255_46_136/0.0)_92%,rgb(255_46_136/0.35)_96%,transparent)] blur-2xl animate-breathe" />
          <div
            className="absolute inset-0 rounded-full"
            style={{
              background: 'radial-gradient(circle at 50% 0%, #2a1020 0%, #120a12 18%, #0a0a0e 40%)',
              boxShadow: 'inset 0 2px 0 rgb(255 179 107 / 0.9), inset 0 24px 60px -18px rgb(255 46 136 / 0.65), 0 -30px 120px -10px rgb(242 92 5 / 0.45)',
            }}
          />
        </div>

        {/* Bottom bar, sitting on the planet surface */}
        <div className="absolute inset-x-0 bottom-0 z-10 px-6 pb-8">
          <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-3 text-sm text-white/45 md:flex-row">
            <p>© {new Date().getFullYear()} IronRank. Built for lifters, on this planet.</p>
            <p>Calorie and strength figures are estimates, not medical advice.</p>
          </div>
        </div>
      </div>
    </footer>
  );
}
