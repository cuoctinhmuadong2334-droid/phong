// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  // Đổi thành địa chỉ thật sau khi deploy (vd: https://ten-cua-ban.vercel.app)
  site: 'https://phong-portfolio.vercel.app',
  integrations: [sitemap()],
  vite: { plugins: [tailwindcss()] },
});
