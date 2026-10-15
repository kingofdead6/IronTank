import Features from './components/Features';
import FinalCta from './components/FinalCta';
import Footer from './components/Footer';
import Gallery from './components/Gallery';
import Hero from './components/Hero';
import Install from './components/Install';
import Navbar from './components/Navbar';
import Ranks from './components/Ranks';
import Stats from './components/Stats';

export default function App() {
  return (
    <div className="min-h-screen overflow-x-hidden bg-ink font-sans">
      <Navbar />
      <main>
        <Hero />
        <Stats />
        <Features />
        <Ranks />
        <Gallery />
        <Install />
        <FinalCta />
      </main>
      <Footer />
    </div>
  );
}
