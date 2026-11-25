import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// Deployed on Vercel (project "sqlpilot", root directory apps/website).
export default defineConfig({
  plugins: [react(), tailwindcss()],
});
