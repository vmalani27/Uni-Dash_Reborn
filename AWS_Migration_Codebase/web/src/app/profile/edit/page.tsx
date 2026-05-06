"use client";

import ProfileForm from "@/components/ProfileForm";
import { Sparkles } from "lucide-react";

export default function ProfileEditPage() {
  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden px-4 py-8 text-[var(--color-on-surface)]">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(103,80,164,0.14),transparent_36%),radial-gradient(circle_at_bottom_right,rgba(103,80,164,0.08),transparent_32%)]" />

      <section className="relative w-full max-w-[880px] overflow-hidden rounded-[var(--radius-card)] border border-[var(--color-outline)] bg-[var(--color-surface)] shadow-[0_18px_60px_rgba(31,29,26,0.12)] dark:shadow-[0_18px_60px_rgba(0,0,0,0.32)]">
        <div className="grid md:grid-cols-[1.05fr_1.25fr]">
          <aside className="flex flex-col justify-between gap-8 border-b border-[var(--color-outline)] bg-[color:rgba(103,80,164,0.05)] p-6 sm:p-8 md:border-b-0 md:border-r">
            <div className="space-y-6">
              <div className="inline-flex items-center gap-2 rounded-full border border-[color:rgba(103,80,164,0.2)] bg-[color:rgba(103,80,164,0.08)] px-3 py-1 text-xs font-medium uppercase tracking-[0.18em] text-[var(--color-primary)]">
                <Sparkles className="h-3.5 w-3.5" />
                Edit profile
              </div>

              <div className="space-y-3">
                <h1 className="text-2xl font-[var(--font-weight-title)] tracking-tight text-[var(--color-on-surface)] sm:text-[2rem]">
                  Edit your profile
                </h1>
                <p className="max-w-sm text-sm leading-6 text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">
                  Update your academic details so UniDash can keep your dashboard accurate.
                </p>
              </div>
            </div>

            <p className="text-xs text-[color:rgba(31,29,26,0.45)] dark:text-[color:rgba(244,239,244,0.45)]">
              © 2026 UniDash
            </p>
          </aside>

          <ProfileForm mode="edit" />
        </div>
      </section>
    </main>
  );
}
