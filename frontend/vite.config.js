import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
// Dev: `npm run dev` (port 5173) forwards /api to Flask on 5000, so cookies/sessions just work.
export default defineConfig({ plugins: [react()], server: { proxy: { '/api': 'http://localhost:5000' } } });
