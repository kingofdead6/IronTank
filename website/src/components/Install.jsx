import Reveal from './Reveal';

const steps = [
  { n: '01', title: 'Download the APK', text: 'Tap the download button on this page from your Android phone.' },
  { n: '02', title: 'Allow the install', text: 'If asked, allow your browser or Files app to "install unknown apps" for this file.' },
  { n: '03', title: 'Open & lift', text: 'Open IronRank, create your free account and start your first workout.' },
];

export default function Install() {
  return (
    <section id="install" className="relative scroll-mt-24 py-28">
      <div className="mx-auto max-w-6xl px-6">
        <Reveal className="mx-auto max-w-2xl text-center">
          <p className="font-display text-sm font-bold uppercase tracking-[0.3em] text-brand">Get started</p>
          <h2 className="mt-4 text-4xl font-black tracking-tight md:text-6xl">Install in three steps</h2>
        </Reveal>
        <div className="relative mt-16 grid gap-6 md:grid-cols-3">
          {/* Connecting line that draws across behind the steps */}
          <div className="pointer-events-none absolute left-[16%] right-[16%] top-12 hidden h-px bg-linear-to-r from-flame/0 via-magenta/50 to-flame/0 md:block" />
          {steps.map((s, i) => (
            <Reveal key={s.n} delay={i * 160}>
              <div className="glass group relative h-full rounded-3xl p-8 text-center transition-transform duration-500 hover:-translate-y-1.5">
                <div className="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-2xl bg-brand font-display text-xl font-bold shadow-lg shadow-magenta/30 transition-transform duration-500 group-hover:rotate-6 group-hover:scale-110">
                  {s.n}
                </div>
                <h3 className="text-xl font-bold">{s.title}</h3>
                <p className="mt-3 text-white/65">{s.text}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
