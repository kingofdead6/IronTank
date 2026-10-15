import Phone from './Phone';
import Reveal from './Reveal';

const shots = [
  { src: './screenshots/home.png', label: 'Dashboard' },
  { src: './screenshots/active_workout_rest.png', label: 'Live workout' },
  { src: './screenshots/pr_celebration.png', label: 'PR celebration' },
  { src: './screenshots/workout_summary.png', label: 'Summary' },
  { src: './screenshots/ranks.png', label: 'Ranks' },
  { src: './screenshots/progress_lower.png', label: 'Progress' },
  { src: './screenshots/calories.png', label: 'Calories' },
  { src: './screenshots/library.png', label: 'Exercise library' },
];

export default function Gallery() {
  // Rendered twice back to back so the marquee loops seamlessly.
  const loop = [...shots, ...shots];
  return (
    <section id="screens" className="relative scroll-mt-24 overflow-hidden py-28">
      <Reveal className="mx-auto max-w-2xl px-6 text-center">
        <p className="font-display text-sm font-bold uppercase tracking-[0.3em] text-brand">Inside the app</p>
        <h2 className="mt-4 text-4xl font-black tracking-tight md:text-6xl">Designed to feel premium</h2>
        <p className="mt-5 text-lg text-white/65">Glass cards, bold numbers and motion everywhere — smooth at 60 fps.</p>
      </Reveal>

      <div className="group relative mt-16 [mask-image:linear-gradient(90deg,transparent,black_12%,black_88%,transparent)]">
        <div className="flex w-max gap-8 animate-marquee group-hover:[animation-play-state:paused]">
          {loop.map((s, i) => (
            <figure key={`${s.label}-${i}`} className="w-56 shrink-0 transition-transform duration-500 hover:-translate-y-3 hover:scale-[1.03] md:w-64">
              <Phone src={s.src} alt={`IronRank ${s.label} screen`} />
              <figcaption className="mt-4 text-center text-sm font-medium text-white/60">{s.label}</figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  );
}
