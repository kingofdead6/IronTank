import Reveal from './Reveal';

const features = [
  {
    icon: '⚡',
    title: 'Lightning-fast logging',
    text: 'Big tap targets, last session’s numbers as ghost text and one tap to complete a set. Built for sweaty hands between sets.',
  },
  {
    icon: '⏱️',
    title: 'Smart rest timer',
    text: 'Starts automatically when you finish a set. ±15 s, skip, and a buzz + sound + notification — even when your phone is locked.',
  },
  {
    icon: '🏆',
    title: 'Automatic PRs',
    text: 'Heaviest lift, estimated 1RM, best set and rep records are detected the moment you save — then celebrated with confetti.',
  },
  {
    icon: '💎',
    title: 'Strength ranks',
    text: 'See how strong you are for your bodyweight on every big lift, per muscle group and overall. Climb from Bronze to Legend.',
  },
  {
    icon: '📈',
    title: 'Progress you can see',
    text: 'e1RM trends, weekly volume, bodyweight, muscle balance and a training calendar heatmap. Streaks keep you coming back.',
  },
  {
    icon: '🥗',
    title: 'Calorie targets',
    text: 'A personal daily target for cutting, maintaining or bulking, macro goals, quick food logging and calories burned in workouts.',
  },
  {
    icon: '📋',
    title: 'Programs that plan your day',
    text: 'Push/Pull/Legs, Upper/Lower, Full Body and 5x5 built in — or build your own with drag and drop. Your next workout is always ready.',
  },
  {
    icon: '📶',
    title: 'Works offline',
    text: 'Every set is saved on your phone instantly. No signal in the basement gym? No problem — it syncs when you’re back online.',
  },
  {
    icon: '🌗',
    title: 'Gorgeous in the dark',
    text: 'A dark-first design with fluid animations and a light mode for daytime. Large-text and screen-reader friendly.',
  },
];

/** A card whose glow follows the cursor. */
function FeatureCard({ icon, title, text }) {
  const onMove = (e) => {
    const r = e.currentTarget.getBoundingClientRect();
    e.currentTarget.style.setProperty('--mx', `${e.clientX - r.left}px`);
    e.currentTarget.style.setProperty('--my', `${e.clientY - r.top}px`);
  };
  return (
    <div
      onMouseMove={onMove}
      className="group glass relative h-full overflow-hidden rounded-3xl p-7 transition-all duration-500 hover:-translate-y-1.5 hover:border-white/25"
    >
      <div
        className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-500 group-hover:opacity-100"
        style={{ background: 'radial-gradient(320px circle at var(--mx) var(--my), rgb(255 46 136 / 0.16), transparent 60%)' }}
      />
      <div className="relative mb-5 flex h-14 w-14 items-center justify-center rounded-2xl bg-white/5 text-3xl ring-1 ring-white/10 transition-transform duration-500 group-hover:scale-110 group-hover:-rotate-6">
        {icon}
      </div>
      <h3 className="relative text-xl font-bold">{title}</h3>
      <p className="relative mt-3 leading-relaxed text-white/65">{text}</p>
    </div>
  );
}

export default function Features() {
  return (
    <section id="features" className="relative scroll-mt-24 py-28">
      <div className="mx-auto max-w-6xl px-6">
        <Reveal className="mx-auto max-w-2xl text-center">
          <p className="font-display text-sm font-bold uppercase tracking-[0.3em] text-brand">Features</p>
          <h2 className="mt-4 text-4xl font-black tracking-tight md:text-6xl">Everything you need to get stronger</h2>
          <p className="mt-5 text-lg text-white/65">No clutter, no ads — just the tools serious lifters actually use, done really well.</p>
        </Reveal>
        <div className="mt-16 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((f, i) => (
            <Reveal key={f.title} delay={(i % 3) * 110}>
              <FeatureCard {...f} />
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
