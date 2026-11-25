import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// Served by GitHub Pages at https://rafay99-epic.github.io/sqlpilot/
export default defineConfig({
  base: "/sqlpilot/",
  plugins: [react(), tailwindcss()],
});
