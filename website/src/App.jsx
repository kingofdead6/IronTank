import { useEffect } from 'react';
import Footer from './components/Footer';
import Navbar from './components/Navbar';
import ScrollProgress from './components/ScrollProgress';
import { policies } from './content/policies';
import Home from './pages/Home';
import NotFound from './pages/NotFound';
import PolicyPage from './pages/PolicyPage';
import { useRoute } from './router';

const titles = { '/': 'IronRank — Lift. Log. Level up.' };

export default function App() {
  const { path, anchor } = useRoute();
  const slug = path.replace(/^\//, '');
  const isPolicy = slug in policies;
  const page = path === '/' ? <Home /> : isPolicy ? <PolicyPage slug={slug} /> : <NotFound />;

  // Page title, then scroll: to the requested section, or to the top on a new page.
  useEffect(() => {
    document.title = titles[path] ?? (isPolicy ? `${policies[slug].title} — IronRank` : 'Lost in orbit — IronRank');
    if (anchor) {
      requestAnimationFrame(() => document.getElementById(anchor)?.scrollIntoView({ behavior: 'smooth' }));
    } else {
      window.scrollTo({ top: 0 });
    }
  }, [path, anchor, slug, isPolicy]);

  return (
    <div className="min-h-screen overflow-x-hidden bg-ink font-sans">
      <ScrollProgress />
      <Navbar />
      {/* Keyed so each page plays its entrance animation. */}
      <main key={path} className="animate-page-in">
        {page}
      </main>
      <Footer />
    </div>
  );
}
