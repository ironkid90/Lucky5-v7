/** @type {import('next').NextConfig} */

// Lucky5 web cabinet Next.js config.
// Proxies `/api/*` and `/assets/*` to the .NET backend so the cabinet can run
// against the same origin in dev without CORS or asset duplication.
//
// Override per-environment via env vars:
//   LUCKY5_API_ORIGIN     — backend origin (default: http://localhost:5000)
//   NEXT_PUBLIC_API_BASE  — leave empty in dev so api.ts uses same-origin
//                            (the rewrites below handle the proxy).

const apiOrigin = process.env.LUCKY5_API_ORIGIN ?? "http://localhost:5000";

const nextConfig = {
  async rewrites() {
    return [
      { source: "/api/:path*", destination: `${apiOrigin}/api/:path*` },
      { source: "/assets/:path*", destination: `${apiOrigin}/assets/:path*` },
    ];
  },
  // Allow `<img src="/assets/...">` without next/image (we use plain img tags
  // in lucky5-cabinet.tsx for parity with the legacy cabinet).
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
