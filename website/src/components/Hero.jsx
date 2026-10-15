import { useCycle } from '../hooks';
import DownloadButton from './DownloadButton';
import Phone from './Phone';

const screens = ['./screenshots/home.png', './screenshots/active_workout_rest.png', './screenshots/ranks.png', './screenshots/progress_lower.png'];
const words = ['Lift.', 'Log.', 'Level', 'up.'];

function FloatingBadge({ className, delay, tilt, children }) {
  return (
    <div
      className={`glass absolute z-20 hidden items-center gap-3 sm:flex rounded-2xl px-4 py-3 shadow-2xl shadow-black/50 animate-float ${className}`}
      style={{ animationDelay: delay, '--tilt': tilt }}
    >
      {children}
    </div>
  );
}

export default function Hero() {
  const active = useCycle(screens.length, 3200);

  return (
    <section id="top" className="relative overflow-hidden pt-36 pb-24 md:pt-44 md:pb-32">
      {/* Animated backdrop */}
      <div className="grid-bg pointer-events-none absolute inset-0" />
      <div className="pointer-events-none absolute -left-32 top-10 h-[28rem] w-[28rem] rounded-full bg-flame/30 blur-[120px] animate-blob" />
      <div
        className="pointer-events-none absolute -right-24 top-40 h-[30rem] w-[30rem] rounded-full bg-magenta/25 blur-[130px] animate-blob"
        style={{ animationDelay: '-6s' }}
      />

      <div className="relative mx-auto grid max-w-6xl items-center gap-16 px-6 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="text-center lg:text-left">
          <div
            className="glass mx-auto mb-7 inline-flex items-center gap-2 rounded-full px-4 py-1.5 text-sm text-white/80 opacity-0 lg:mx-0"
            style={{ animation: 'reveal-in 0.8s cubic-bezier(.2,0,0,1) forwards' }}
          >
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-400" />
            </span>
            Free gym tracker · Works offline
          </div>

          <h1 className="font-sans text-6xl font-black leading-[0.95] tracking-tight sm:text-7xl md:text-8xl">
            {words.map((w, i) => (
              <span
                key={w}
                className={`mr-4 inline-block opacity-0 ${i >= 2 ? 'text-brand animate-gradient' : ''}`}
                style={{ animation: `reveal-in 0.9s cubic-bezier(.2,0,0,1) ${150 + i * 120}ms forwards${i >= 2 ? ', gradient 8s ease infinite' : ''}` }}
              >
                {w}
              </span>
            ))}
          </h1>

          <p
            className="mx-auto mt-7 max-w-xl text-lg leading-relaxed text-white/70 opacity-0 md:text-xl lg:mx-0"
            style={{ animation: 'reveal-in 0.9s cubic-bezier(.2,0,0,1) 650ms forwards' }}
          >
            The workout logger that keeps up with you. Automatic personal records, strength ranks from{' '}
            <span className="font-semibold text-[#e09a5f]">Bronze</span> to{' '}
            <span className="font-semibold text-brand">Legend</span>, smart programs and calorie targets — in one beautifully fast app.
          </p>

          <div
            className="mt-10 flex flex-col items-center gap-5 opacity-0 sm:flex-row sm:items-start sm:justify-center lg:justify-start"
            style={{ animation: 'reveal-in 0.9s cubic-bezier(.2,0,0,1) 800ms forwards' }}
          >
            <DownloadButton />
            <a
              href="#features"
              className="group inline-flex items-center gap-2 rounded-full border border-white/15 px-7 py-4 text-lg font-semibold text-white/85 transition-all duration-300 hover:border-white/40 hover:bg-white/5"
            >
              See features
              <span className="transition-transform duration-300 group-hover:translate-x-1">→</span>
            </a>
          </div>
        </div>

        {/* Phone with rotating screenshots and floating stat badges */}
        <div
          className="relative mx-auto w-full max-w-[19rem] opacity-0 sm:max-w-[21rem]"
          style={{ animation: 'phone-in 1.2s cubic-bezier(.2,0,0,1) 300ms forwards' }}
        >
          <div className="absolute inset-x-6 bottom-0 top-10 rounded-[3rem] bg-brand opacity-40 blur-3xl animate-glow" />
          <div className="animate-float-slow">
            <Phone screens={screens} active={active} />
          </div>

          <FloatingBadge className="-left-10 top-24 sm:-left-20" delay="-1s" tilt="-6deg">
            <span className="text-2xl">🏆</span>
            <div>
              <p className="text-xs text-white/60">New bench PR</p>
              <p className="font-display text-lg font-bold">
                102.5 <span className="text-sm text-white/60">kg</span> <span className="text-sm text-emerald-400">+2.5</span>
              </p>
            </div>
          </FloatingBadge>

          <FloatingBadge className="-right-6 top-1/2 sm:-right-16" delay="-3.5s" tilt="5deg">
            <span className="hex h-9 w-8 bg-linear-to-br from-[#7ff5e1] to-[#14a38b]" />
            <div>
              <p className="text-xs text-white/60">Rank up</p>
              <p className="font-display text-lg font-bold text-[#7ff5e1]">Platinum</p>
            </div>
          </FloatingBadge>

          <FloatingBadge className="-left-6 bottom-16 sm:-left-14" delay="-2s" tilt="3deg">
            <span className="text-2xl">🔥</span>
            <div>
              <p className="text-xs text-white/60">Streak</p>
              <p className="font-display text-lg font-bold">6 weeks</p>
            </div>
          </FloatingBadge>

          {/* Screen indicator dots */}
          <div className="mt-8 flex justify-center gap-2">
            {screens.map((s, i) => (
              <span
                key={s}
                className={`h-1.5 rounded-full transition-all duration-500 ${i === active ? 'w-8 bg-brand' : 'w-1.5 bg-white/25'}`}
              />
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
