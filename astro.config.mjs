// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: import.meta.env['PUBLIC_SITE_URL'] || 'https://palm-agate-nursery.vercel.app',
  integrations: [
    sitemap(),
  ],
  vite: {
    ssr: {
      noExternal: ['@supabase/supabase-js'],
    },
  },
});
