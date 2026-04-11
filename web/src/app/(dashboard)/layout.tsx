"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { onAuthStateChanged, User } from "firebase/auth";
import { auth } from "@/lib/firebase/firebase";

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const router = useRouter();

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      if (!currentUser) {
        router.push("/");
      } else {
        setUser(currentUser);
      }
    });

    return () => unsubscribe();
  }, [router]);

  if (!user) {
    return null; // or a loading spinner
  }

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-zinc-950 flex flex-col text-zinc-900 dark:text-zinc-100">
      {/* minimal nav header */}
      <header className="sticky top-0 z-40 bg-zinc-50/80 dark:bg-zinc-950/80 backdrop-blur-md border-b border-zinc-200 dark:border-zinc-800">
        <div className="max-w-6xl mx-auto w-full px-6 h-14 flex items-center justify-between">
          <span className="font-semibold text-sm tracking-tight text-zinc-900 dark:text-zinc-100">UniDash.</span>
          <nav className="flex gap-4 text-sm font-medium text-zinc-500 dark:text-zinc-400">
            <a href="/dashboard" className="text-zinc-900 dark:text-zinc-100">Inbox</a>
            <a href="#" className="hover:text-zinc-900 dark:hover:text-zinc-100 transition-colors">Calendar</a>
            <a href="#" className="hover:text-zinc-900 dark:hover:text-zinc-100 transition-colors">Settings</a>
          </nav>
        </div>
      </header>

      {/* main content area */}
      <main className="flex-1 w-full max-w-6xl mx-auto p-6 md:p-8">
        {children}
      </main>
    </div>
  );
}