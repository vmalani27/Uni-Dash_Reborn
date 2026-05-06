"use client";

import { useSearchParams, useRouter } from "next/navigation";
import ProfileForm from "@/components/ProfileForm";
import { BadgeCheck, BookOpen, X } from "lucide-react";

export default function ProfileSetupPage() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const mode = (searchParams.get("mode") || "setup") as "setup" | "edit";

  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden px-4 py-8 text-[var(--color-on-surface)]">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(103,80,164,0.14),transparent_36%),radial-gradient(circle_at_bottom_right,rgba(103,80,164,0.08),transparent_32%)]" />

      <section className="relative w-full max-w-[880px] overflow-hidden rounded-[var(--radius-card)] border border-[var(--color-outline)] bg-[var(--color-surface)] shadow-[0_18px_60px_rgba(31,29,26,0.12)] dark:shadow-[0_18px_60px_rgba(0,0,0,0.32)]">
                {mode === "edit" && (
                  <button
                    onClick={() => router.back()}
                    className="absolute right-4 top-4 z-10 p-2 text-[var(--color-on-surface)] hover:bg-[color:rgba(31,29,26,0.05)] rounded-[var(--radius-tile)] transition-colors dark:hover:bg-[color:rgba(244,239,244,0.05)]"
                    aria-label="Close profile edit"
                  >
                    <X className="h-5 w-5" />
                  </button>
                )}
        <div className="grid md:grid-cols-[1.05fr_1.25fr]">
          <aside className="flex flex-col justify-between gap-8 border-b border-[var(--color-outline)] bg-[color:rgba(103,80,164,0.05)] p-6 sm:p-8 md:border-b-0 md:border-r">
            <div className="space-y-6">

              <div className="space-y-3">
                <h1 className="text-2xl font-[var(--font-weight-title)] tracking-tight text-[var(--color-on-surface)] sm:text-[2rem]">
                  {mode === "setup" ? "Complete your profile" : "Edit your profile"}
                </h1>
                <p className="max-w-sm text-sm leading-6 text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">
                  {mode === "setup"
                    ? "Add your academic details once so UniDash can shape the dashboard around your student life."
                    : "Update your branch and year of admission to keep your profile current."}
                </p>
              </div>

              <div className="space-y-3">
                <div className="flex items-center gap-3 rounded-[var(--radius-tile)] border border-[var(--color-outline)] bg-[var(--color-surface)] px-4 py-3">
                  <BadgeCheck className="h-5 w-5 text-[var(--color-primary)]" />
                  <div>
                    <p className="text-sm font-[var(--font-weight-value)] text-[var(--color-on-surface)]">Secure account sync</p>
                    <p className="text-xs text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">Secure profile creation</p>
                  </div>
                </div>

                <div className="flex items-center gap-3 rounded-[var(--radius-tile)] border border-[var(--color-outline)] bg-[var(--color-surface)] px-4 py-3">
                  <BookOpen className="h-5 w-5 text-[var(--color-primary)]" />
                  <div>
                    <p className="text-sm font-[var(--font-weight-value)] text-[var(--color-on-surface)]">Personalized schedule</p>
                    <p className="text-xs text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">Built from your degree and branch</p>
                  </div>
                </div>
              </div>
            </div>

            <p className="text-xs text-[color:rgba(31,29,26,0.45)] dark:text-[color:rgba(244,239,244,0.45)]">
              © 2026 UniDash
            </p>
          </aside>

          <ProfileForm mode={mode} />
        </div>
      </section>
    </main>
  );
}
