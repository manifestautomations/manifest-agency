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
  title: "Manifest Agency | AI Staffing & Growth Infrastructure",
  description: "We deploy autonomous AI Recruiters, SDRs, and Receptionists that speak, sell, and work 24/7. Scale your agency without scaling your headcount.",
  openGraph: {
    title: "Manifest Agency | AI Staffing & Growth Infrastructure",
    description: "Stop hiring humans for robot work. We automate your workforce.",
    url: "https://manifest.agency",
    siteName: "Manifest Agency",
    locale: "en_US",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Manifest Agency | AI Staffing & Growth Infrastructure",
    description: "Stop hiring humans for robot work. We automate your workforce.",
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
