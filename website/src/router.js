import { useEffect, useState } from 'react';

/**
 * Minimal hash router (no dependency, works on any static host):
 *   #/privacy, #/terms, ...  → pages
 *   #features, #top, ...     → sections on the home page
 *   anything else under #/   → not found
 */
function parse() {
  const hash = window.location.hash;
  if (hash.startsWith('#/')) return { path: hash.slice(1).split('?')[0] || '/', anchor: null };
  return { path: '/', anchor: hash ? decodeURIComponent(hash.slice(1)) : null };
}

export function useRoute() {
  const [route, setRoute] = useState(parse);
  useEffect(() => {
    const onChange = () => setRoute(parse());
    window.addEventListener('hashchange', onChange);
    return () => window.removeEventListener('hashchange', onChange);
  }, []);
  return route;
}

/** Link targets used across the site. */
export const paths = {
  home: '#/',
  privacy: '#/privacy',
  terms: '#/terms',
  disclaimer: '#/disclaimer',
};
