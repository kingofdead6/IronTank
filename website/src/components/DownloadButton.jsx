import { APP_SIZE, APP_VERSION, DOWNLOAD_URL, MIN_ANDROID } from '../config';

function AndroidIcon({ className }) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" className={className} aria-hidden="true">
      <path d="M17.6 9.48l1.84-3.18a.5.5 0 10-.87-.5l-1.86 3.22A11.4 11.4 0 0012 8.1c-1.67 0-3.25.35-4.71.92L5.43 5.8a.5.5 0 10-.87.5L6.4 9.48A10.5 10.5 0 001.5 18h21a10.5 10.5 0 00-4.9-8.52zM7 15.25a1.25 1.25 0 110-2.5 1.25 1.25 0 010 2.5zm10 0a1.25 1.25 0 110-2.5 1.25 1.25 0 010 2.5z" />
    </svg>
  );
}

/**
 * The primary call to action. Reads the link from src/config.js; while it's
 * empty the button is disabled and says "Coming soon".
 */
export default function DownloadButton({ size = 'lg', showMeta = true }) {
  const ready = DOWNLOAD_URL.trim().length > 0;
  const big = size === 'lg';
  const meta = [`v${APP_VERSION}`, APP_SIZE, MIN_ANDROID].filter(Boolean).join(' · ');

  return (
    <div className="flex flex-col items-center gap-3 sm:items-start">
      <a
        href={ready ? DOWNLOAD_URL : undefined}
        download={ready ? '' : undefined}
        aria-disabled={!ready}
        className={`group relative inline-flex items-center gap-3 overflow-hidden rounded-full font-bold text-white transition-transform duration-300
          ${big ? 'px-8 py-4 text-lg' : 'px-5 py-2.5 text-sm'}
          ${ready ? 'bg-brand animate-gradient animate-glow hover:scale-105 active:scale-95 cursor-pointer' : 'bg-ink-3 border border-white/10 cursor-not-allowed opacity-80'}`}
      >
        {/* Moving highlight that sweeps across the button. */}
        {ready && (
          <span className="pointer-events-none absolute inset-y-0 left-0 w-1/3 bg-linear-to-r from-transparent via-white/40 to-transparent animate-shine" />
        )}
        <AndroidIcon className={`${big ? 'h-6 w-6' : 'h-4 w-4'} transition-transform duration-300 group-hover:-rotate-12 group-hover:scale-110`} />
        <span className="relative">{ready ? 'Download for Android' : 'Coming soon'}</span>
        {ready && (
          <svg viewBox="0 0 24 24" className={`${big ? 'h-5 w-5' : 'h-4 w-4'} transition-transform duration-300 group-hover:translate-y-0.5`} fill="none" stroke="currentColor" strokeWidth="2.5" aria-hidden="true">
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v12m0 0l-5-5m5 5l5-5M5 20h14" />
          </svg>
        )}
      </a>
      {showMeta && big && <p className="text-sm text-muted">{ready ? `Free · ${meta}` : `${meta} · download link coming soon`}</p>}
    </div>
  );
}
