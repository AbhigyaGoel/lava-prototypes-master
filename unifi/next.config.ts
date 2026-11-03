import type { NextConfig } from "next";

const config: NextConfig = {
  // PGlite ships WASM; keep it out of the server bundle.
  serverExternalPackages: ["@electric-sql/pglite"],
  // Sign-in was removed (seeded account). Send old bookmarks to the app instead of a 404.
  async redirects() {
    return [{ source: "/sign-in", destination: "/", permanent: false }];
  },
};

export default config;
