import Features from '../components/Features';
import FinalCta from '../components/FinalCta';
import Gallery from '../components/Gallery';
import Hero from '../components/Hero';
import Install from '../components/Install';
import Ranks from '../components/Ranks';
import Stats from '../components/Stats';

export default function Home() {
  return (
    <>
      <Hero />
      <Stats />
      <Features />
      <Ranks />
      <Gallery />
      <Install />
      <FinalCta />
    </>
  );
}
