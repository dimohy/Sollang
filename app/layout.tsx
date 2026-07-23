import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Sollang Playground",
  description: "Write, compile, and run Sollang directly in your browser.",
  metadataBase: new URL("https://sollang.slogs.dev"),
  openGraph: {
    title: "Sollang Playground",
    description: "A flow-first language, running entirely in your browser.",
    url: "https://sollang.slogs.dev",
    siteName: "Sollang",
    type: "website"
  }
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
