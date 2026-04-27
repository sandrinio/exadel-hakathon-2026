import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  output: "static",
  site: "https://hakathon2026.soula.ge",
  vite: {
    plugins: [tailwindcss()],
  },
});
