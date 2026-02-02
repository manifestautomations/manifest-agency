import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Manifest Agency | Automated Data Infrastructure",
  description: "We build automated data pipelines that ingest, clean, and report your client data instantly. Scale your agency without scaling your headcount.",
  openGraph: {
    title: "Manifest Agency | Automated Data Infrastructure",
    description: "Stop hiring analysts to do robot work. We automate your data stack.",
    url: "https://manifest.agency",
    siteName: "Manifest Agency",
    locale: "en_US",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Manifest Agency | Automated Data Infrastructure",
    description: "Stop hiring analysts to do robot work. We automate your data stack.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
