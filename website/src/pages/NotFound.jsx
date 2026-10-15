import Starfield from '../components/Starfield';
import { paths } from '../router';

/** "Lost in orbit": a planet with a dumbbell circling it like a satellite. */
export default function NotFound() {
  return (
    <section className="relative flex min-h-screen items-center justify-center overflow-hidden px-6 pt-28 pb-16">
      <Starfield count={140} seed={404} />
      <div className="pointer-events-none absolute left-1/2 top-1/2 h-[40rem] w-[40rem] -translate-x-1/2 -translate-y-1/2 rounded-full bg-magenta/15 blur-[140px]" />

      <div className="relative z-10 flex flex-col items-center text-center">
        {/* Planet + orbit */}
        <div className="relative h-72 w-72 md:h-80 md:w-80" aria-hidden="true">
          <div className="absolute inset-8 rounded-full bg-[radial-gradient(circle_at_30%_25%,#ff9a5a,#f25c05_35%,#b0185a_70%,#3a0a24)] shadow-[0_0_80px_rgba(255,46,136,0.45),inset_-20px_-30px_60px_rgba(0,0,0,0.55)] animate-float-slow" />
          {/* Planet rings */}
          <div className="absolute left-1/2 top-1/2 h-24 w-[130%] -translate-x-1/2 -translate-y-1/2 -rotate-12 rounded-[50%] border-2 border-white/15" />
          {/* Orbiting dumbbell */}
          <div className="absolute inset-0 animate-spin-slow">
            <div className="absolute -top-2 left-1/2 -translate-x-1/2 text-4xl drop-shadow-[0_0_12px_rgba(255,255,255,0.6)]">🏋️</div>
          </div>
        </div>

        <h1 className="mt-6 font-display text-8xl font-bold tracking-tighter md:text-9xl">
          <span className="text-brand animate-gradient">404</span>
        </h1>
        <p className="mt-4 text-2xl font-bold md:text-3xl">Lost in orbit</p>
        <p className="mt-3 max-w-md text-lg text-white/60">This page drifted out of range — or it skipped leg day. Let’s get you back to base.</p>
        <div className="mt-10 flex flex-wrap justify-center gap-4">
          <a
            href={paths.home}
            className="group relative inline-flex items-center gap-2 overflow-hidden rounded-full bg-brand px-8 py-4 text-lg font-bold animate-gradient animate-glow transition-transform hover:scale-105"
          >
            <span className="transition-transform duration-300 group-hover:-translate-x-1">←</span> Back to home
          </a>
          <a href="#features" className="rounded-full border border-white/15 px-8 py-4 text-lg font-semibold text-white/80 transition-colors hover:border-white/40 hover:bg-white/5">
            Explore features
          </a>
        </div>
      </div>
    </section>
  );
}
