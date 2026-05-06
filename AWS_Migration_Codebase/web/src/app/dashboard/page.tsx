"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useDashboardData } from "@/hooks/useDashboard";
import { CalendarDays, LayoutGrid, Sparkles } from "lucide-react";
import { useProfile } from "@/hooks/useProfile";
import { isCompleteUserProfile } from "@/lib/profileCache";

type TabKey = "assignments" | "exams" | "opportunities" | "admin";

const TABS: { key: TabKey; label: string; backendKey: string }[] = [
  { key: "assignments", label: "Assignments", backendKey: "ASSIGNMENT" },
  { key: "exams", label: "Exams", backendKey: "EXAM" },
  { key: "opportunities", label: "Opportunities", backendKey: "OPPORTUNITY" },
  { key: "admin", label: "Announcements", backendKey: "ACADEMIC_ADMIN" },
];

export default function DashboardPage() {
  const router = useRouter();
  const { profile, isLoading: isProfileLoading } = useProfile();
  const { data, isLoading, error } = useDashboardData();
  const [activeTab, setActiveTab] = useState<TabKey>("assignments");

  useEffect(() => {
    if (!isProfileLoading && !isCompleteUserProfile(profile)) {
      router.replace("/profile-setup?mode=setup");
    }
  }, [isProfileLoading, profile, router]);

  if (isProfileLoading || !isCompleteUserProfile(profile)) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p className="text-sm text-zinc-500">Preparing your profile...</p>
      </main>
    );
  }

  if (isLoading && !data) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p className="text-sm text-zinc-500">Loading dashboard...</p>
      </main>
    );
  }

  if (error && !data) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p className="text-sm text-red-500">Failed to load dashboard</p>
      </main>
    );
  }

  const sections = data?.sections || {};
  const timeline = data?.timeline || [];
  const focus = data?.focus;

  const currentTab = TABS.find((t) => t.key === activeTab)!;
  const items = sections[currentTab.backendKey] || [];

  return (
    <main className="min-h-screen px-4 py-6 sm:px-6 sm:py-8">
      <div className="mx-auto flex max-w-7xl gap-6">

        {/* LEFT COLUMN */}
        <div className="flex-1 space-y-6">

          {/* Focus Card */}
          {focus && (
            <div className="app-card p-4">
              <div className="mb-2 inline-flex items-center gap-2 rounded-full border border-[color:rgba(103,80,164,0.18)] bg-[color:rgba(103,80,164,0.08)] px-2.5 py-1 text-[10px] font-medium uppercase tracking-[0.18em] text-[var(--color-primary)]">
                <Sparkles className="h-3.5 w-3.5" />
                Focus
              </div>
              <p className="text-sm font-semibold text-[var(--color-on-surface)]">
                {focus.title}
              </p>
              {focus.description && (
                <p className="mt-1 text-xs app-muted">
                  {focus.description}
                </p>
              )}
            </div>
          )}

          {/* Tabs */}
          <div className="flex gap-4 border-b border-[var(--color-outline)]">
            {TABS.map((tab) => (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                className={`pb-2 text-xs font-medium uppercase tracking-wide transition-colors ${
                  activeTab === tab.key
                    ? "border-b-2 border-[var(--color-primary)] text-[var(--color-on-surface)]"
                    : "text-[color:rgba(31,29,26,0.58)] hover:text-[var(--color-on-surface)] dark:text-[color:rgba(244,239,244,0.58)]"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* Items List */}
          <div className="space-y-3">
            {items.length === 0 ? (
              <p className="text-sm app-muted">No items</p>
            ) : (
              items.map((item: any) => (
                <div
                  key={item.id}
                  className="app-card p-4 text-sm"
                >
                  <p className="font-medium text-[var(--color-on-surface)]">
                    {item.title}
                  </p>
                  {item.description && (
                    <p className="mt-1 text-xs app-muted">
                      {item.description}
                    </p>
                  )}
                </div>
              ))
            )}
          </div>
        </div>

        {/* RIGHT COLUMN (Timeline) */}
        <div className="hidden w-80 shrink-0 space-y-4 lg:block">
          <div className="mb-2 inline-flex items-center gap-2 rounded-full border border-[color:rgba(103,80,164,0.18)] bg-[color:rgba(103,80,164,0.08)] px-2.5 py-1 text-[10px] font-medium uppercase tracking-[0.18em] text-[var(--color-primary)]">
            <CalendarDays className="h-3.5 w-3.5" />
            Timeline
          </div>

          {timeline.length === 0 ? (
            <p className="text-sm app-muted">No upcoming events</p>
          ) : (
            timeline.map((group: any) => (
              <div key={group.date} className="space-y-2">
                <p className="text-xs app-muted">{group.date}</p>
                {group.items.map((item: any) => (
                  <div
                    key={item.id}
                    className="app-card p-2 text-xs"
                  >
                    {item.title}
                  </div>
                ))}
              </div>
            ))
          )}
        </div>
      </div>
    </main>
  );
}
