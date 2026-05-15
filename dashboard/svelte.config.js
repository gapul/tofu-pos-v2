import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter({
      pages: 'build',
      assets: 'build',
      // 全ルートを prerender する SPA。fallback は不要だが、Cloudflare Pages 側で
      // 想定外パスにも index.html を返すなら fallback を指定するとよい。
      fallback: undefined,
      precompress: false,
      strict: true,
    }),
  },
};

export default config;
