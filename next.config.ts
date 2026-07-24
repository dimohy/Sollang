import type { NextConfig } from "next";

const isGitHubPages = process.env.GITHUB_PAGES === "true";

const nextConfig: NextConfig = {
  poweredByHeader: false,
  ...(isGitHubPages
    ? {
        output: "export" as const,
        assetPrefix: ".",
        trailingSlash: true
      }
    : {}),
  experimental: {
    optimizePackageImports: ["lucide-react"]
  }
};

export default nextConfig;
