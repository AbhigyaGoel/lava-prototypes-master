import type { Metadata } from "next";
import { Geist, Geist_Mono, Noto_Serif } from "next/font/google";
import "./globals.css";

const sans = Geist({ subsets: ["latin"], variable: "--font-geist" });
const mono = Geist_Mono({ subsets: ["latin"], variable: "--font-geist-mono" });
// Greek-letter chapter monograms
const serif = Noto_Serif({ subsets: ["greek"], weight: ["500"], variable: "--font-greek" });

export const metadata: Metadata = {
  title: "Greenlight",
  description: "Annual chapter compliance review for national headquarters",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`h-full antialiased ${sans.variable} ${mono.variable} ${serif.variable}`}>
      <body className="min-h-full font-sans">{children}</body>
    </html>
  );
}
