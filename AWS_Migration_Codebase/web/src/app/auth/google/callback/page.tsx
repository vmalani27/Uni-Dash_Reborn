"use client";

import { useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";

export default function OAuthCallbackPage() {
  const router = useRouter();
  const searchParams = useSearchParams();

  useEffect(() => {
    const callbackBaseUrl = `${process.env.NEXT_PUBLIC_API_BASE_URL}/auth/google/callback`;
    const queryString = searchParams.toString();
    const callbackUrl = queryString
      ? `${callbackBaseUrl}?${queryString}`
      : callbackBaseUrl;

    if (!process.env.NEXT_PUBLIC_API_BASE_URL) {
      router.replace("/profile?oauth_error=missing_api_base_url");
      return;
    }

    window.location.href = callbackUrl;
  }, [router, searchParams]);

  return (
    <main className="min-h-screen flex items-center justify-center px-4 py-8">
      <p className="text-sm text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">
        Connecting Google account...
      </p>
    </main>
  );
}
