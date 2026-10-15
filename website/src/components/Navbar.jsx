import { useEffect, useState } from 'react';
import DownloadButton from './DownloadButton';

const links = [
  { href: '#features', label: 'Features' },
  { href: '#ranks', label: 'Ranks' },
  { href: '#screens', label: 'Screens' },
  { href: '#install', label: 'Install' },
];

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <header className="fixed inset-x-0 top-0 z-50 flex justify-center px-4 pt-4">
      <nav
        className={`flex w-full max-w-6xl items-center justify-between rounded-full px-4 py-2.5 transition-all duration-500 ${
          scrolled ? 'glass shadow-2xl shadow-black/40' : 'bg-transparent'
        }`}
      >
        <a href="#top" className="group flex items-center gap-2.5" aria-label="IronRank home">
          <img src="./icon.png" alt="" className="h-9 w-9 rounded-xl transition-transform duration-500 group-hover:rotate-12 group-hover:scale-110" />
          <span className="font-display text-lg font-bold tracking-wider">
            IRON<span className="text-brand">RANK</span>
          </span>
        </a>
        <div className="hidden items-center gap-8 md:flex">
          {links.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="relative text-sm font-medium text-white/70 transition-colors hover:text-white after:absolute after:-bottom-1 after:left-0 after:h-0.5 after:w-0 after:rounded-full after:bg-brand after:transition-all after:duration-300 hover:after:w-full"
            >
              {l.label}
            </a>
          ))}
        </div>
        <DownloadButton size="sm" showMeta={false} />
      </nav>
    </header>
  );
}
