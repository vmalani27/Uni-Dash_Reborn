"use client";

import { useState } from "react";
import { useDashboardData } from "@/hooks/useDashboard";

type TabKey = "assignments" | "exams" | "opportunities" | "admin";

const TABS: { key: TabKey; label: string; backendKey: string }[] = [
  { key: "assignments", label: "Assignments", backendKey: "ASSIGNMENT" },
  { key: "exams", label: "Exams", backendKey: "EXAM" },
  { key: "opportunities", label: "Opportunities", backendKey: "OPPORTUNITY" },
  { key: "admin", label: "Announcements", backendKey: "ACADEMIC_ADMIN" },
];

export default function DashboardPage() {
  const { data, isLoading, error } = useDashboardData();
  const [activeTab, setActiveTab] = useState<TabKey>("assignments");

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
    <main className="min-h-screen bg-zinc-50 px-6 py-6 dark:bg-zinc-950">
      <div className="mx-auto flex max-w-7xl gap-6">

        {/* LEFT COLUMN */}
        <div className="flex-1 space-y-6">

          {/* Focus Card */}
          {focus && (
            <div className="rounded-lg border border-zinc-200/60 bg-white/60 p-4 dark:border-zinc-800/60 dark:bg-zinc-900/40">
              <p className="mb-1 text-xs uppercase tracking-wide text-zinc-500">
                Focus
              </p>
              <p className="text-sm font-semibold text-zinc-900 dark:text-zinc-100">
                {focus.title}
              </p>
              {focus.description && (
                <p className="mt-1 text-xs text-zinc-600 dark:text-zinc-400">
                  {focus.description}
                </p>
              )}
            </div>
          )}

          {/* Tabs */}
          <div className="flex gap-4 border-b border-zinc-200 dark:border-zinc-800">
            {TABS.map((tab) => (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                className={`pb-2 text-xs font-medium uppercase tracking-wide transition-colors ${
                  activeTab === tab.key
                    ? "border-b-2 border-zinc-900 text-zinc-900 dark:border-zinc-100 dark:text-zinc-100"
                    : "text-zinc-500 hover:text-zinc-700 dark:text-zinc-400 dark:hover:text-zinc-200"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* Items List */}
          <div className="space-y-3">
            {items.length === 0 ? (
              <p className="text-sm text-zinc-500">No items</p>
            ) : (
              items.map((item: any) => (
                <div
                  key={item.id}
                  className="rounded-lg border border-zinc-200/60 bg-white/60 p-4 text-sm dark:border-zinc-800/60 dark:bg-zinc-900/40"
                >
                  <p className="font-medium text-zinc-900 dark:text-zinc-100">
                    {item.title}
                  </p>
                  {item.description && (
                    <p className="mt-1 text-xs text-zinc-600 dark:text-zinc-400">
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
          <p className="text-xs uppercase tracking-wide text-zinc-500">
            Timeline
          </p>

          {timeline.length === 0 ? (
            <p className="text-sm text-zinc-500">No upcoming events</p>
          ) : (
            timeline.map((group: any) => (
              <div key={group.date} className="space-y-2">
                <p className="text-xs text-zinc-500">{group.date}</p>
                {group.items.map((item: any) => (
                  <div
                    key={item.id}
                    className="rounded-md border border-zinc-200/60 bg-white/60 p-2 text-xs dark:border-zinc-800/60 dark:bg-zinc-900/40"
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