"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { signOut } from "@/lib/cognito";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean | null>(null);
  const router = useRouter();

  useEffect(() => {
    const token = localStorage.getItem("idToken");

    if (!token) {
      router.replace("/");
    } else {
      setIsAuthenticated(true);
    }
  }, []);

  const handleLogout = () => {
    signOut();
    router.replace("/");
  };

  if (isAuthenticated === null) {
    return null;
  }

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-zinc-950 flex flex-col text-zinc-900 dark:text-zinc-100">
      <header className="sticky top-0 z-40 bg-zinc-50/80 dark:bg-zinc-950/80 backdrop-blur-md border-b border-zinc-200 dark:border-zinc-800">
        <div className="max-w-6xl mx-auto w-full px-6 h-14 flex items-center justify-between">
          <span className="font-semibold text-sm tracking-tight">
            UniDash.
          </span>

          <nav className="flex items-center gap-4 text-sm font-medium text-zinc-500 dark:text-zinc-400">
            <a href="/dashboard" className="text-zinc-900 dark:text-zinc-100">
              Inbox
            </a>

            <a
              href="/profile-setup"
              className="hover:text-zinc-900 dark:hover:text-zinc-100 transition-colors"
            >
              Profile
            </a>

            <button
              onClick={handleLogout}
              className="rounded-md border border-zinc-300 px-3 py-1.5 text-xs text-zinc-700 hover:bg-zinc-100 dark:border-zinc-700 dark:text-zinc-300 dark:hover:bg-zinc-800"
            >
              Logout
            </button>
          </nav>
        </div>
      </header>

      <main className="flex-1 w-full max-w-6xl mx-auto p-6 md:p-8">
        {children}
      </main>
    </div>
  );
}
