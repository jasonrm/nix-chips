import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

// Rewrite /*.md requests to /data/*.md so Vite serves them from public/data/
function markdownRewrite(): Plugin {
  return {
    name: "markdown-rewrite",
    configureServer(server) {
      server.middlewares.use((req, _res, next) => {
        if (req.url?.endsWith(".md") && !req.url.startsWith("/data/")) {
          req.url = `/data${req.url}`;
        }
        next();
      });
    },
  };
}

export default defineConfig({
  plugins: [markdownRewrite(), react(), tailwindcss()],
  build: {
    outDir: "dist",
  },
});
