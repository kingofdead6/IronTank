import { useEffect, useState } from 'react';
import Reveal from '../components/Reveal';
import { LAST_UPDATED, policies, policyOrder } from '../content/policies';
import { paths } from '../router';

const icons = { privacy: '🔒', terms: '📜', disclaimer: '❤️‍🩹' };

/** Highlights the section currently in view (scroll-spy). */
function useActiveSection(ids) {
  const [active, setActive] = useState(ids[0]);
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
        if (visible[0]) setActive(visible[0].target.id);
      },
      { rootMargin: '-25% 0px -65% 0px' },
    );
    ids.forEach((id) => {
      const el = document.getElementById(id);
      if (el) observer.observe(el);
    });
    return () => observer.disconnect();
  }, [ids]);
  return active;
}

function Body({ body }) {
  return body.map((block, i) =>
    typeof block === 'string' ? (
      <p key={i} className="mt-4 leading-relaxed text-white/70">
        {block}
      </p>
    ) : (
      <ul key={i} className="mt-4 space-y-2.5">
        {block.list.map((item) => (
          <li key={item} className="flex gap-3 leading-relaxed text-white/70">
            <span className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-brand" />
            <span>{item}</span>
          </li>
        ))}
      </ul>
    ),
  );
}

export default function PolicyPage({ slug }) {
  const policy = policies[slug];
  const ids = policy.sections.map((s) => s.id);
  const active = useActiveSection(ids);

  const jump = (id) => (e) => {
    e.preventDefault();
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  return (
    <section className="relative px-6 pt-36 pb-24">
      <div className="pointer-events-none absolute left-1/2 top-0 h-80 w-[50rem] -translate-x-1/2 rounded-full bg-magenta/15 blur-[130px]" />

      <div className="relative mx-auto max-w-6xl">
        {/* Header */}
        <Reveal className="text-center">
          <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-3xl bg-white/5 text-3xl ring-1 ring-white/10 animate-float">{icons[slug]}</div>
          <h1 className="mt-6 text-5xl font-black tracking-tight md:text-6xl">{policy.title}</h1>
          <p className="mt-4 text-lg text-white/60">{policy.tagline}</p>
          <p className="mt-2 text-sm text-white/40">Last updated {LAST_UPDATED}</p>
        </Reveal>

        {/* Switch between policies */}
        <Reveal delay={100} className="mt-10 flex justify-center">
          <div className="glass inline-flex flex-wrap justify-center gap-1 rounded-full p-1.5">
            {policyOrder.map((key) => (
              <a
                key={key}
                href={paths[key]}
                className={`rounded-full px-5 py-2 text-sm font-semibold transition-all duration-300 ${
                  key === slug ? 'bg-brand text-white shadow-lg shadow-magenta/30' : 'text-white/60 hover:bg-white/5 hover:text-white'
                }`}
              >
                {policies[key].title}
              </a>
            ))}
          </div>
        </Reveal>

        <div className="mt-14 grid gap-10 lg:grid-cols-[16rem_1fr]">
          {/* Table of contents with scroll-spy */}
          <aside className="hidden lg:block">
            <nav className="sticky top-28" aria-label="On this page">
              <p className="font-display text-xs font-bold uppercase tracking-[0.25em] text-white/40">On this page</p>
              <ul className="mt-4 space-y-1 border-l border-white/10">
                {policy.sections.map((s) => (
                  <li key={s.id}>
                    <a
                      href={`#/${slug}`}
                      onClick={jump(s.id)}
                      className={`-ml-px block border-l-2 py-1.5 pl-4 text-sm transition-all duration-300 ${
                        active === s.id ? 'border-magenta font-semibold text-white' : 'border-transparent text-white/50 hover:text-white/80'
                      }`}
                    >
                      {s.heading}
                    </a>
                  </li>
                ))}
              </ul>
            </nav>
          </aside>

          <div className="glass rounded-[2rem] p-7 md:p-12">
            {policy.sections.map((s, i) => (
              <Reveal key={s.id} as="article" id={s.id} delay={Math.min(i, 3) * 60} className="scroll-mt-32 border-b border-white/5 py-8 first:pt-0 last:border-0 last:pb-0">
                <h2 className="flex items-center gap-3 text-2xl font-bold">
                  <span className="font-display text-sm text-brand">{String(i + 1).padStart(2, '0')}</span>
                  {s.heading}
                </h2>
                <Body body={s.body} />
              </Reveal>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
