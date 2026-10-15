/**
 * A phone frame. Pass several [screens] to crossfade between them
 * (controlled by [active]), or a single [src].
 */
export default function Phone({ src, screens, active = 0, className = '', alt = 'IronRank app screen' }) {
  const images = screens ?? [src];
  return (
    <div
      className={`relative aspect-[412/915] w-full rounded-[2.6rem] border border-white/15 bg-ink-2 p-2.5 shadow-[0_40px_120px_-30px_rgba(255,46,136,0.45)] ${className}`}
    >
      {/* Side buttons */}
      <span className="absolute -left-[3px] top-28 h-14 w-[3px] rounded-l bg-white/15" />
      <span className="absolute -right-[3px] top-24 h-20 w-[3px] rounded-r bg-white/15" />
      <div className="relative h-full w-full overflow-hidden rounded-[2.1rem] bg-ink">
        {images.map((img, i) => (
          <img
            key={img}
            src={img}
            alt={i === active ? alt : ''}
            loading={i === 0 ? 'eager' : 'lazy'}
            className={`absolute inset-0 h-full w-full object-cover transition-all duration-1000 ease-out ${
              i === active ? 'scale-100 opacity-100' : 'scale-105 opacity-0'
            }`}
          />
        ))}
        {/* Camera notch */}
        <div className="absolute left-1/2 top-2 h-5 w-24 -translate-x-1/2 rounded-full bg-black/90" />
        {/* Glass reflection */}
        <div className="pointer-events-none absolute inset-0 bg-linear-to-br from-white/10 via-transparent to-transparent" />
      </div>
    </div>
  );
}
