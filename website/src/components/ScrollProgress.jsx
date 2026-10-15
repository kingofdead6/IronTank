import { useEffect, useState } from 'react';

/** 0 → 1 as the page scrolls from top to bottom. */
function useScrollProgress() {
  const [progress, setProgress] = useState(0);
  useEffect(() => {
    let frame = 0;
    const update = () => {
      frame = 0;
      const max = document.documentElement.scrollHeight - window.innerHeight;
      setProgress(max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0);
    };
    const onScroll = () => {
      if (!frame) frame = requestAnimationFrame(update);
    };
    update();
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    return () => {
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onScroll);
      cancelAnimationFrame(frame);
    };
  }, []);
  return progress;
}

const RING = 2 * Math.PI * 22; // circumference of the back-to-top ring (r = 22)

/**
 * A comet streaking along the top edge as you scroll, plus a floating
 * back-to-top button whose gradient ring fills with your progress.
 */
export default function ScrollProgress() {
  const p = useScrollProgress();

  return (
    <>
      {/* Top progress comet */}
      <div className="pointer-events-none fixed inset-x-0 top-0 z-[60] h-[3px]" aria-hidden="true">
        <div
          className="relative h-full origin-left bg-[linear-gradient(90deg,transparent,#f25c05_30%,#ff2e88)]"
          style={{ transform: `scaleX(${p})` }}
        />
        <div
          className="absolute top-1/2 h-3 w-3 -translate-x-1/2 -translate-y-1/2 rounded-full bg-white shadow-[0_0_12px_4px_rgba(255,46,136,0.9),0_0_30px_8px_rgba(242,92,5,0.5)] transition-opacity duration-300"
          style={{ left: `${p * 100}%`, opacity: p > 0.005 && p < 0.995 ? 1 : 0 }}
        />
      </div>

      {/* Back to top */}
      <button
        type="button"
        onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
        aria-label={`Back to top (${Math.round(p * 100)}% scrolled)`}
        className={`group fixed bottom-6 right-6 z-50 flex h-14 w-14 items-center justify-center rounded-full bg-ink-2/80 backdrop-blur-md transition-all duration-500 hover:scale-110 ${
          p > 0.08 ? 'translate-y-0 opacity-100' : 'pointer-events-none translate-y-6 opacity-0'
        }`}
      >
        <svg className="absolute inset-0 -rotate-90" viewBox="0 0 48 48" aria-hidden="true">
          <defs>
            <linearGradient id="ringGrad" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stopColor="#f25c05" />
              <stop offset="1" stopColor="#ff2e88" />
            </linearGradient>
          </defs>
          <circle cx="24" cy="24" r="22" fill="none" stroke="rgb(255 255 255 / 0.1)" strokeWidth="2.5" />
          <circle
            cx="24"
            cy="24"
            r="22"
            fill="none"
            stroke="url(#ringGrad)"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeDasharray={RING}
            strokeDashoffset={RING * (1 - p)}
          />
        </svg>
        <svg className="relative h-5 w-5 transition-transform duration-300 group-hover:-translate-y-1" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" aria-hidden="true">
          <path strokeLinecap="round" strokeLinejoin="round" d="M12 19V5m0 0l-6 6m6-6l6 6" />
        </svg>
      </button>
    </>
  );
}
