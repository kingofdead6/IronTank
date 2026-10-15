# IronRank website

Landing page where people download the IronRank Android app. Built with React 19, Tailwind CSS 4 and Vite. All animations are plain CSS and React; there's no animation library.

## Add your download link

Open **[`src/config.js`](src/config.js)** and paste the APK URL:

```js
export const DOWNLOAD_URL = 'https://example.com/ironrank.apk';
```

Every Download button uses this value. While it's empty, the buttons show "Coming soon". In the same file you can also set the version, size and minimum Android version shown under the button.

## Run & build

```bash
npm install
npm run dev       # http://localhost:5173 with hot reload
npm run build     # static site in dist/
npm run preview   # serve the built site locally
```

`dist/` is a fully static site that uses relative paths, so it works on any static host: Netlify, Vercel, GitHub Pages, Render static sites or your own server. Upload the contents of `dist/`.

## Updating the screenshots

The screenshots in `public/screenshots/` are copied from `docs/screenshots/`, which the app's widget tests render. After regenerating them, copy the new PNGs here.
