/** @type {import('next').NextConfig} */

// Lucky5 web cabinet Next.js config.
// Dev mode: proxies `/api/*` and `/assets/*` to the .NET backend via rewrites.
// Production: uses `output: 'export'` for static hosting served from the .NET API.
//
// Override per-environment via env vars:
//   LUCKY5_API_ORIGIN     — backend origin (default: http://localhost:5000)
//   NEXT_PUBLIC_API_BASE  — leave empty so api.ts uses same-origin

const isExport = process.env.NEXT_EXPORT === "1" || process.env.NODE_ENV === "production";

const apiOrigin = process.env.LUCKY5_API_ORIGIN ?? "http://localhost:5000";

const nextConfig = {
  output: isExport ? "export" : undefined,
  async rewrites() {
    if (isExport) return [];
    return [
      { source: "/api/:path*", destination: `${apiOrigin}/api/:path*` },
      { source: "/assets/:path*", destination: `${apiOrigin}/assets/:path*` },
    ];
  },
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
