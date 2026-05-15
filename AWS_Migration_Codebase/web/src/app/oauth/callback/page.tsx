"use client";

import { useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";

export default function OAuthCallbackPage() {
  const router = useRouter();
  const searchParams = useSearchParams();

  useEffect(() => {
    const code = searchParams.get("code");
    const state = searchParams.get("state");
    if (!code) {
      router.replace("/profile?oauth_error=missing_code");
      return;
    }

    try {
      const saved = typeof window !== "undefined" ? localStorage.getItem("cognito_oauth_state") : null;
      if (state && saved && state === saved) {
        localStorage.removeItem("cognito_oauth_state");
        // Let backend handle token capture; frontend redirects to dashboard
        router.replace("/dashboard");
        return;
      }
    } catch {
      // ignore localStorage errors
    }

    // State mismatch or missing: clear and redirect to profile with error
    try {
      localStorage.removeItem("cognito_oauth_state");
    } catch {}
    router.replace("/profile?oauth_error=state_mismatch");
  }, [searchParams, router]);

  return (
    <main className="min-h-screen flex items-center justify-center px-4 py-8">
      <p className="text-sm text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">Connecting Google account...</p>
    </main>
  );
}
