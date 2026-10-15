export default function Footer() {
  return (
    <footer className="border-t border-white/5 px-6 py-10">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 text-sm text-white/50 md:flex-row">
        <div className="flex items-center gap-2.5">
          <img src="./icon.png" alt="" className="h-7 w-7 rounded-lg" />
          <span className="font-display font-bold tracking-wider text-white/80">
            IRON<span className="text-brand">RANK</span>
          </span>
        </div>
        <p>© {new Date().getFullYear()} IronRank. Calorie and strength figures are estimates, not medical advice.</p>
        <p>
          Exercise data from{' '}
          <a href="https://github.com/yuhonas/free-exercise-db" className="underline decoration-white/30 underline-offset-4 hover:text-white">
            free-exercise-db
          </a>
        </p>
      </div>
    </footer>
  );
}
