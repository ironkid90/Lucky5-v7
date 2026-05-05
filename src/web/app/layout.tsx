import type { Metadata, Viewport } from "next";

import "./globals.css";

export const metadata: Metadata = {
  title: "Lucky5 Cabinet",
  description:
    "Lucky5 retro arcade cabinet — 5-card draw with Ranked Full House, 4-of-a-Kind A/B, Straight Flush and Kent jackpots, plus the 5-card double-up bonus.",
  applicationName: "Lucky5",
  themeColor: "#060606",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  themeColor: "#060606",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>
        <div className="page-shell">{children}</div>
      </body>
    </html>
  );
}
