"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { signOut } from "@/lib/cognito";
import { getAuthToken } from "@/lib/api";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean | null>(null);
  const router = useRouter();

  useEffect(() => {
    let isMounted = true;

    const checkAuth = async () => {
      const token = await getAuthToken();

      if (!isMounted) {
        return;
      }

      if (!token) {
        router.replace("/");
        return;
      }

      setIsAuthenticated(true);
    };

    void checkAuth();

    return () => {
      isMounted = false;
    };
  }, [router]);

  const handleLogout = () => {
    signOut();
    router.replace("/");
  };

  if (isAuthenticated === null) {
    return null;
  }

  return (
    <div className="app-shell flex flex-col">
      <header className="sticky top-0 z-40 border-b border-[var(--color-outline)] bg-[color:rgba(255,255,255,0.72)] backdrop-blur-md dark:bg-[color:rgba(29,27,32,0.72)]">
        <div className="mx-auto flex h-16 w-full max-w-6xl items-center justify-between px-6">
          <span className="text-sm font-semibold tracking-tight text-[var(--color-on-surface)]">
            UniDash.
          </span>

          <nav className="flex items-center gap-4 text-sm font-medium text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">
            <Link href="/dashboard" className="text-[var(--color-on-surface)]">
              Inbox
            </Link>

            <Link
              href="/profile"
              className="transition-colors hover:text-[var(--color-on-surface)]"
            >
              Profile
            </Link>

            <button
              onClick={handleLogout}
              className="rounded-[var(--radius-button)] border border-[var(--color-outline)] bg-[var(--color-surface)] px-3 py-1.5 text-xs text-[var(--color-on-surface)] transition-colors hover:bg-[color:rgba(103,80,164,0.06)]"
            >
              Logout
            </button>
          </nav>
        </div>
      </header>

      <main className="mx-auto w-full max-w-6xl flex-1 p-6 md:p-8">
        {children}
      </main>
    </div>
  );
}
