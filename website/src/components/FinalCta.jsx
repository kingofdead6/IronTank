import DownloadButton from './DownloadButton';
import Reveal from './Reveal';

export default function FinalCta() {
  return (
    <section className="relative px-6 pb-28">
      <Reveal className="relative mx-auto max-w-5xl overflow-hidden rounded-[2.5rem] p-[1.5px]">
        {/* Animated gradient border */}
        <div className="absolute inset-0 bg-brand animate-gradient" />
        <div className="relative overflow-hidden rounded-[2.4rem] bg-ink-2 px-8 py-16 text-center md:px-16 md:py-20">
          <div className="pointer-events-none absolute -top-24 left-1/2 h-64 w-[36rem] -translate-x-1/2 rounded-full bg-magenta/25 blur-[100px] animate-blob" />
          <img src="./icon.png" alt="" className="relative mx-auto h-20 w-20 rounded-3xl shadow-2xl shadow-magenta/40 animate-float" />
          <h2 className="relative mt-8 text-4xl font-black tracking-tight md:text-6xl">
            Your next PR is <span className="text-brand animate-gradient">one tap away</span>
          </h2>
          <p className="relative mx-auto mt-5 max-w-xl text-lg text-white/65">Free. No ads. Download IronRank and start your first workout in under a minute.</p>
          <div className="relative mt-10 flex justify-center">
            <DownloadButton />
          </div>
        </div>
      </Reveal>
    </section>
  );
}
