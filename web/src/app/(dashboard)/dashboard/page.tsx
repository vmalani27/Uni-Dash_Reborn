"use client";

import { useState } from "react";
import { useDashboardData, type DashboardPayload } from "@/hooks/useDashboard";
import { Maximize2, Minus, X, Clock, AlertCircle, BookOpen, Award } from "lucide-react";

interface SyncItem {
  id: string | number;
  title: string;
  entity_type: string;
  description?: string;
  due_date?: string;
  course_code?: string;
  location?: string;
  academic_score?: number;
  effective_score?: number;
  urgency_boost?: number;
  decay_factor?: number;
  metadata?: Record<string, unknown>;
}

interface TimelineGroup {
  date: string;
  items: SyncItem[];
}

type TabKey = "assignments" | "exams" | "opportunities" | "admin";
type ItemWorkspaceStatus = "active" | "snoozed" | "dismissed";
type SnoozeOptionKey = "1h" | "3h" | "today" | "tomorrow";

interface WorkspaceItemRecord {
  status: ItemWorkspaceStatus;
  snoozedUntil?: string | null;
}

type WorkspaceState = Record<TabKey, Record<string, WorkspaceItemRecord>>;

const BUCKET_CATEGORIES: { key: TabKey; label: string }[] = [
  { key: "assignments", label: "Assignments" },
  { key: "exams", label: "Exams" },
  { key: "opportunities", label: "Opportunities" },
  { key: "admin", label: "Announcements" },
];

const SNOOZE_OPTIONS: Array<{ key: SnoozeOptionKey; label: string; durationMs: number }> = [
  { key: "1h", label: "1 hour", durationMs: 60 * 60 * 1000 },
  { key: "3h", label: "3 hours", durationMs: 3 * 60 * 60 * 1000 },
  { key: "today", label: "Later today", durationMs: 6 * 60 * 60 * 1000 },
  { key: "tomorrow", label: "Tomorrow", durationMs: 24 * 60 * 60 * 1000 },
];

function getEntityLabel(entityType?: string) {
  switch (entityType?.toUpperCase()) {
    case "ASSIGNMENT":
      return "Assignment";
    case "EXAM":
      return "Exam";
    case "OPPORTUNITY":
      return "Opportunity";
    case "ACADEMIC_ADMIN":
      return "Announcement";
    case "INFORMATION":
      return "Information";
    default:
      return entityType || "Item";
  }
}

function categoryToEntityType(categoryKey: TabKey) {
  switch (categoryKey) {
    case "assignments":
      return "ASSIGNMENT";
    case "exams":
      return "EXAM";
    case "opportunities":
      return "OPPORTUNITY";
    case "admin":
      return "ACADEMIC_ADMIN";
  }
}

function getTabKeyFromEntityType(entityType?: string): TabKey {
  switch (entityType?.toUpperCase()) {
    case "ASSIGNMENT":
      return "assignments";
    case "EXAM":
      return "exams";
    case "OPPORTUNITY":
      return "opportunities";
    case "ACADEMIC_ADMIN":
      return "admin";
    default:
      return "assignments";
  }
}

function normalizeScore(score?: number) {
  if (typeof score !== "number" || Number.isNaN(score)) {
    return 0;
  }

  const maybePercentage = score <= 1 ? score * 100 : score;
  return Math.min(100, Math.max(0, maybePercentage));
}

function getPriorityTier(score?: number) {
  const normalized = normalizeScore(score);

  if (normalized >= 70) return "HIGH";
  if (normalized >= 40) return "MEDIUM";
  return "LOW";
}

function getPriorityTone(tier: "HIGH" | "MEDIUM" | "LOW") {
  switch (tier) {
    case "HIGH":
      return "text-zinc-900 dark:text-zinc-100";
    case "MEDIUM":
      return "text-zinc-700 dark:text-zinc-300";
    case "LOW":
      return "text-zinc-500 dark:text-zinc-400";
  }
}

function getPriorityDot(tier: "HIGH" | "MEDIUM" | "LOW") {
  switch (tier) {
    case "HIGH":
      return "bg-zinc-700 dark:bg-zinc-200";
    case "MEDIUM":
      return "bg-zinc-500 dark:bg-zinc-400";
    case "LOW":
      return "bg-zinc-400 dark:bg-zinc-600";
  }
}

function formatDeadline(dateValue?: string) {
  if (!dateValue) {
    return "No deadline";
  }

  const parsedDate = new Date(dateValue);

  if (Number.isNaN(parsedDate.getTime())) {
    return dateValue;
  }

  const datePart = parsedDate.toLocaleDateString(undefined, { month: "short", day: "numeric" });
  const timePart = dateValue.includes("T")
    ? parsedDate.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" })
    : "";

  return timePart ? `${datePart} - ${timePart}` : datePart;
}

function getPriorityIcon(type: string) {
  switch (type?.toUpperCase()) {
    case "EXAM":
      return <AlertCircle className="h-4 w-4" />;
    case "ASSIGNMENT":
      return <BookOpen className="h-4 w-4" />;
    case "OPPORTUNITY":
      return <Award className="h-4 w-4" />;
    default:
      return <Clock className="h-4 w-4" />;
  }
}

function getItemScore(item: SyncItem) {
  return normalizeScore(item.effective_score ?? item.academic_score);
}

function getDueDateSnoozeLimit(item: SyncItem) {
  if (!item.due_date) {
    return null;
  }

  const dueDate = new Date(item.due_date).getTime();
  if (Number.isNaN(dueDate)) {
    return null;
  }

  return dueDate - 12 * 60 * 60 * 1000;
}

function getSnoozeTarget(optionKey: SnoozeOptionKey) {
  const option = SNOOZE_OPTIONS.find((entry) => entry.key === optionKey);
  return option ? Date.now() + option.durationMs : Date.now() + 60 * 60 * 1000;
}

function getAcademicItems(payload: DashboardPayload | null): SyncItem[] {
  if (!payload || !Array.isArray(payload.academic_items)) {
    return [];
  }

  return payload.academic_items as SyncItem[];
}

function getTimelineGroups(payload: DashboardPayload | null): TimelineGroup[] {
  if (!payload || !Array.isArray(payload.timeline)) {
    return [];
  }

  return payload.timeline as TimelineGroup[];
}

function getInformationItems(items: SyncItem[]) {
  return items.filter((item) => item.entity_type?.toUpperCase() === "INFORMATION").slice(0, 5);
}

function FocusCard({ item }: { item: SyncItem | null }) {
  if (!item) return null;
  const tier = getPriorityTier(getItemScore(item));

  return (
    <section className="rounded-[14px] border border-zinc-200/60 bg-white/70 p-4 dark:border-zinc-800/60 dark:bg-zinc-900/35">
      <div className="mb-3 flex items-center gap-2 text-[10px] font-medium uppercase tracking-[0.18em] text-zinc-500 dark:text-zinc-500">
        <span className="inline-flex h-4 w-4 items-center justify-center rounded-full bg-zinc-100 text-zinc-600 dark:bg-zinc-800 dark:text-zinc-300">
          {getPriorityIcon(item.entity_type)}
        </span>
        Focus
      </div>

      <div className="flex items-start gap-3">
        <div className="min-w-0 flex-1">
          <div className="mb-2 flex flex-wrap items-center gap-2 text-[10px] text-zinc-500 dark:text-zinc-500">
            <span className={`inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 font-medium uppercase tracking-wide ${getPriorityTone(tier)}`}>
              <span className={`h-1 w-1 rounded-full ${getPriorityDot(tier)}`} />
              {tier}
            </span>
            {item.course_code && <span>{item.course_code}</span>}
          </div>

          <h3 className="line-clamp-2 text-lg font-semibold leading-tight text-zinc-900 dark:text-zinc-100">
            {item.title}
          </h3>

          {item.description && (
            <p className="mt-2 line-clamp-2 text-sm leading-6 text-zinc-600 dark:text-zinc-400">
              {item.description}
            </p>
          )}
        </div>
      </div>

      <div className="mt-3 flex items-center justify-between gap-3 border-t border-zinc-200/70 pt-3 text-xs text-zinc-500 dark:border-zinc-800/70 dark:text-zinc-500">
        <span>{formatDeadline(item.due_date)}</span>
      </div>
    </section>
  );
}

function BucketTabs({
  activeTab,
  onSelect,
  snoozedCounts,
}: {
  activeTab: TabKey;
  onSelect: (tab: TabKey) => void;
  snoozedCounts: Record<TabKey, number>;
}) {
  return (
    <div className="flex flex-wrap gap-x-4 gap-y-2 border-b border-zinc-200/70 pb-3 dark:border-zinc-800/70">
      {BUCKET_CATEGORIES.map((cat) => {
        const isActive = activeTab === cat.key;
        const hasMinimized = (snoozedCounts[cat.key] || 0) > 0;

        return (
          <button
            key={cat.key}
            onClick={() => onSelect(cat.key)}
            className={`inline-flex items-center gap-2 border-b-2 px-0 pb-2 text-sm whitespace-nowrap transition-colors ${
              isActive
                ? "border-zinc-900 text-zinc-900 dark:border-zinc-100 dark:text-zinc-100"
                : "border-transparent text-zinc-600 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-200"
            }`}
          >
            <span className="font-medium">{cat.label}</span>
            {hasMinimized && <span className="text-zinc-400 dark:text-zinc-500">•</span>}
          </button>
        );
      })}
    </div>
  );
}

function ItemCard({
  item,
  showCategoryLabel = false,
  snoozeMenuOpen = false,
  onDismiss,
  onToggleSnoozeMenu,
  onSnoozeOption,
  snoozeDisabledOptions,
}: {
  item: SyncItem;
  showCategoryLabel?: boolean;
  snoozeMenuOpen?: boolean;
  onDismiss: () => void;
  onToggleSnoozeMenu: () => void;
  onSnoozeOption: (option: SnoozeOptionKey) => void;
  snoozeDisabledOptions: Record<SnoozeOptionKey, boolean>;
}) {
  const tier = getPriorityTier(getItemScore(item));

  return (
    <article className="group relative rounded-[12px] border border-zinc-200/60 bg-white/70 p-3 pr-9 transition-colors hover:border-zinc-300/80 dark:border-zinc-800/60 dark:bg-zinc-900/35 dark:hover:border-zinc-700/80">
      <div className="absolute right-2 top-2 flex items-center gap-1">
        <button
          type="button"
          title="Snooze"
          aria-label="Snooze"
          onClick={onToggleSnoozeMenu}
          className="rounded-full p-1 text-zinc-400 transition-colors hover:bg-zinc-100 hover:text-zinc-700 dark:hover:bg-zinc-800 dark:hover:text-zinc-200"
        >
          <Minus className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          title="Dismiss"
          aria-label="Dismiss"
          onClick={onDismiss}
          className="rounded-full p-1 text-zinc-400 transition-colors hover:bg-zinc-100 hover:text-zinc-700 dark:hover:bg-zinc-800 dark:hover:text-zinc-200"
        >
          <X className="h-3.5 w-3.5" />
        </button>
      </div>

      {snoozeMenuOpen && (
        <div className="absolute right-2 top-10 z-10 w-36 rounded-lg border border-zinc-200/80 bg-white p-1 shadow-sm dark:border-zinc-800/80 dark:bg-zinc-950">
          {SNOOZE_OPTIONS.map((option) => {
            const disabled = snoozeDisabledOptions[option.key];
            return (
              <button
                key={option.key}
                type="button"
                disabled={disabled}
                onClick={() => onSnoozeOption(option.key)}
                className="w-full rounded-md px-2 py-1.5 text-left text-xs text-zinc-600 transition-colors hover:bg-zinc-100 hover:text-zinc-900 disabled:cursor-not-allowed disabled:opacity-40 dark:text-zinc-400 dark:hover:bg-zinc-900 dark:hover:text-zinc-100"
              >
                {option.label}
              </button>
            );
          })}
        </div>
      )}

      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <div className="mb-2 flex flex-wrap items-center gap-2 text-[10px] text-zinc-500 dark:text-zinc-500">
            <span className={`inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 font-medium uppercase tracking-wide ${getPriorityTone(tier)}`}>
              <span className={`h-1 w-1 rounded-full ${getPriorityDot(tier)}`} />
              {tier}
            </span>
            {showCategoryLabel && <span>{getEntityLabel(item.entity_type)}</span>}
            {item.course_code && <span>{item.course_code}</span>}
          </div>

          <h4 className="line-clamp-2 text-sm font-medium leading-5 text-zinc-900 transition-colors group-hover:text-zinc-700 dark:text-zinc-100 dark:group-hover:text-zinc-200">
            {item.title}
          </h4>

          {item.description && (
            <p className="mt-1 line-clamp-2 text-xs leading-5 text-zinc-600 dark:text-zinc-400">
              {item.description}
            </p>
          )}
        </div>
      </div>

      <div className="mt-3 flex items-center justify-between gap-3 text-[11px] text-zinc-500 dark:text-zinc-500">
        <span>{formatDeadline(item.due_date)}</span>
      </div>
    </article>
  );
}

function WorkspaceFab({
  items,
  open,
  onToggle,
  onRestore,
}: {
  items: SyncItem[];
  open: boolean;
  onToggle: () => void;
  onRestore: (id: string) => void;
}) {
  if (items.length === 0) return null;

  return (
    <div className="absolute bottom-4 right-4 z-20">
      {open && (
        <div className="mb-2 w-72 origin-bottom-right rounded-[14px] border border-zinc-200/80 bg-white/95 p-2 shadow-sm backdrop-blur transition-all duration-150 ease-out dark:border-zinc-800/80 dark:bg-zinc-950/95">
          <div className="mb-2 px-2 text-[10px] font-medium uppercase tracking-[0.2em] text-zinc-500 dark:text-zinc-500">
            Minimized
          </div>
          <div className="space-y-1">
            {items.length === 0 ? (
              <div className="px-2 py-1 text-xs text-zinc-500 dark:text-zinc-400">No minimized items</div>
            ) : (
              items.map((item) => (
                <div
                  key={item.id}
                  className="flex items-center justify-between gap-2 rounded-lg px-2 py-1.5 text-xs text-zinc-600 transition-colors hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-zinc-900"
                >
                  <span className="min-w-0 flex-1 truncate" title={item.title}>
                    {item.title}
                  </span>
                  <button
                    type="button"
                    onClick={() => onRestore(String(item.id))}
                    aria-label="Maximize"
                    title="Maximize"
                    className="rounded-full p-1 text-zinc-400 transition-colors hover:bg-zinc-200 hover:text-zinc-700 dark:hover:bg-zinc-800 dark:hover:text-zinc-200"
                  >
                    <Maximize2 className="h-3.5 w-3.5" />
                  </button>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      <button
        type="button"
        onClick={onToggle}
        className="inline-flex items-center gap-2 rounded-full border border-zinc-200/80 bg-white/90 px-3 py-2 text-xs font-medium text-zinc-600 transition-all duration-150 ease-out hover:border-zinc-300 hover:text-zinc-900 dark:border-zinc-800/80 dark:bg-zinc-950/90 dark:text-zinc-400 dark:hover:border-zinc-700 dark:hover:text-zinc-200"
      >
        <span aria-hidden="true">⌄</span>
        <span>{items.length}</span>
      </button>
    </div>
  );
}

function TimelineSection({ groups }: { groups: TimelineGroup[] }) {
  if (groups.length === 0) return <div className="text-xs text-zinc-500">No upcoming events</div>;

  return (
    <div className="space-y-4">
      {groups.map((dayGroup, idx) => (
        <section key={idx} className="space-y-2">
          <div className="flex items-center gap-2 text-xs font-medium uppercase tracking-[0.2em] text-zinc-500 dark:text-zinc-500">
            <span className="h-px w-3 bg-zinc-300 dark:bg-zinc-700" />
            {dayGroup.date}
          </div>
          <div className="space-y-2 pl-4">
            {dayGroup.items?.slice(0, 3).map((item) => (
              <div
                key={item.id}
                className="rounded-lg border border-zinc-200/60 bg-white/60 p-3 text-xs transition-colors hover:border-zinc-300/80 dark:border-zinc-800/60 dark:bg-zinc-900/35 dark:hover:border-zinc-700/80"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0 flex-1">
                    <div className="mb-1 flex flex-wrap items-center gap-2 text-[10px] text-zinc-500 dark:text-zinc-500">
                      <span className="rounded-full bg-zinc-100 px-2 py-0.5 font-medium uppercase tracking-wide text-zinc-600 dark:bg-zinc-800 dark:text-zinc-400">
                        {getEntityLabel(item.entity_type)}
                      </span>
                      {item.course_code && <span>{item.course_code}</span>}
                    </div>
                    <p className="line-clamp-1 font-medium text-zinc-900 dark:text-zinc-100">{item.title}</p>
                  </div>
                  {item.due_date && (
                    <span className="flex-shrink-0 text-[10px] text-zinc-500 dark:text-zinc-500">
                      {formatDeadline(item.due_date)}
                    </span>
                  )}
                </div>
              </div>
            ))}
            {dayGroup.items?.length > 3 && (
              <div className="px-3 text-[10px] font-medium text-zinc-500 dark:text-zinc-500">
                +{dayGroup.items.length - 3} more
              </div>
            )}
          </div>
        </section>
      ))}
    </div>
  );
}

function ContextFeed({ items }: { items: SyncItem[] }) {
  if (items.length === 0) return <div className="text-xs text-zinc-500">No recent information</div>;

  return (
    <div className="space-y-2">
      {items.map((item) => (
        <div
          key={item.id}
          className="rounded-lg border border-zinc-200/60 bg-white/60 p-3 text-xs transition-colors hover:border-zinc-300/80 dark:border-zinc-800/60 dark:bg-zinc-900/35 dark:hover:border-zinc-700/80"
        >
          <div className="flex items-start gap-2">
            <div className="mt-1 h-1.5 w-1.5 flex-shrink-0 rounded-full bg-zinc-400 dark:bg-zinc-600" />
            <div className="min-w-0 flex-1">
              <div className="mb-1 flex flex-wrap items-center gap-2 text-[10px] text-zinc-500 dark:text-zinc-500">
                <span className="rounded-full bg-zinc-100 px-2 py-0.5 font-medium uppercase tracking-wide text-zinc-600 dark:bg-zinc-800 dark:text-zinc-400">
                  {getEntityLabel(item.entity_type)}
                </span>
                {item.course_code && <span>{item.course_code}</span>}
              </div>
              <p className="line-clamp-1 font-medium text-zinc-900 transition-colors dark:text-zinc-100">
                {item.title}
              </p>
              {item.description && <p className="mt-1 line-clamp-1 text-zinc-600 dark:text-zinc-400">{item.description}</p>}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

export default function DashboardPage() {
  const { data: dashboardData, isLoading, error } = useDashboardData();
  const [activeTab, setActiveTab] = useState<TabKey>("assignments");
  const [workspaceState, setWorkspaceState] = useState<WorkspaceState>({
    assignments: {},
    exams: {},
    opportunities: {},
    admin: {},
  });
  const [openSnoozeMenuItem, setOpenSnoozeMenuItem] = useState<string | null>(null);
  const [openMinimizedPanelByTab, setOpenMinimizedPanelByTab] = useState<Record<TabKey, boolean>>({
    assignments: false,
    exams: false,
    opportunities: false,
    admin: false,
  });

  const allItems = getAcademicItems(dashboardData);
  const timelineGroups = getTimelineGroups(dashboardData);
  const informationItems = getInformationItems(allItems);

  const groupedData: Record<TabKey, SyncItem[]> = {
    assignments: allItems.filter((item) => item.entity_type?.toUpperCase() === categoryToEntityType("assignments")),
    exams: allItems.filter((item) => item.entity_type?.toUpperCase() === categoryToEntityType("exams")),
    opportunities: allItems.filter((item) => item.entity_type?.toUpperCase() === categoryToEntityType("opportunities")),
    admin: allItems.filter((item) => item.entity_type?.toUpperCase() === categoryToEntityType("admin")),
  };

  const getItemRecord = (tab: TabKey, itemId: string): WorkspaceItemRecord => {
    return workspaceState[tab][itemId] || { status: "active" };
  };

  const updateItemState = (tab: TabKey, itemId: string, status: ItemWorkspaceStatus, snoozedUntil?: string | null) => {
    setWorkspaceState((prev) => ({
      ...prev,
      [tab]: {
        ...prev[tab],
        [itemId]: { status, snoozedUntil: snoozedUntil ?? null },
      },
    }));
  };

  const restoreItem = (tab: TabKey, itemId: string) => {
    updateItemState(tab, itemId, "active", null);
  };

  const snoozeItem = (tab: TabKey, itemId: string, item: SyncItem, optionKey: SnoozeOptionKey) => {
    const limit = getDueDateSnoozeLimit(item);
    const targetTime = getSnoozeTarget(optionKey);

    if (limit !== null && targetTime > limit) {
      return;
    }

    updateItemState(tab, itemId, "snoozed", new Date(targetTime).toISOString());
    setOpenSnoozeMenuItem(null);
  };

  const currentTabItems = groupedData[activeTab];
  const boardItems = currentTabItems.filter((item) => getItemRecord(activeTab, String(item.id)).status === "active");
  const minimizedItems = currentTabItems.filter((item) => getItemRecord(activeTab, String(item.id)).status === "snoozed");

  const globalActiveItems = allItems.filter((item) => {
    const itemTab = getTabKeyFromEntityType(item.entity_type);
    return getItemRecord(itemTab, String(item.id)).status === "active";
  });

  const focusItem =
    [...globalActiveItems].sort((left, right) => {
      const leftScore = getItemScore(left);
      const rightScore = getItemScore(right);

      if (leftScore !== rightScore) {
        return rightScore - leftScore;
      }

      const leftTime = left.due_date ? new Date(left.due_date).getTime() : Number.POSITIVE_INFINITY;
      const rightTime = right.due_date ? new Date(right.due_date).getTime() : Number.POSITIVE_INFINITY;
      return leftTime - rightTime;
    })[0] || null;

  const minimizedCounts: Record<TabKey, number> = {
    assignments: groupedData.assignments.filter((item) => getItemRecord("assignments", String(item.id)).status === "snoozed").length,
    exams: groupedData.exams.filter((item) => getItemRecord("exams", String(item.id)).status === "snoozed").length,
    opportunities: groupedData.opportunities.filter((item) => getItemRecord("opportunities", String(item.id)).status === "snoozed").length,
    admin: groupedData.admin.filter((item) => getItemRecord("admin", String(item.id)).status === "snoozed").length,
  };

  const selectTab = (tab: TabKey) => {
    setActiveTab(tab);
    setOpenSnoozeMenuItem(null);
  };

  const toggleMinimizedPanel = (tab: TabKey) => {
    setOpenMinimizedPanelByTab((prev) => ({
      ...prev,
      [tab]: !prev[tab],
    }));
  };

  const restoreFromMinimized = (tab: TabKey, itemId: string) => {
    restoreItem(tab, itemId);
  };

  if (isLoading && allItems.length === 0) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-6 pb-28 sm:px-6 lg:px-8">
        <div className="h-96 rounded-lg bg-zinc-200 animate-pulse dark:bg-zinc-700" />
      </div>
    );
  }

  if (error && allItems.length === 0) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
        <div className="rounded-[14px] border border-red-200 bg-red-50/70 p-4 text-sm text-red-700 dark:border-red-900 dark:bg-red-950/30 dark:text-red-200">
          Failed to load dashboard data.
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <FocusCard item={focusItem} />

          <div className="relative overflow-hidden rounded-[14px] border border-zinc-200/60 bg-white/60 pb-16 dark:border-zinc-800/60 dark:bg-zinc-900/35">
            <div className="px-4 pt-4">
              <BucketTabs activeTab={activeTab} onSelect={selectTab} snoozedCounts={minimizedCounts} />
            </div>

            <div className="px-4 py-4">
              {boardItems.length === 0 ? (
                <div className="flex min-h-[180px] items-center justify-center rounded-[12px] border border-dashed border-zinc-200/70 bg-white/50 px-4 py-6 text-center text-sm text-zinc-500 dark:border-zinc-800/70 dark:bg-zinc-900/25 dark:text-zinc-400">
                  <span>No active items in this workspace.</span>
                </div>
              ) : (
                <div className="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-3">
                  {boardItems.map((item) => (
                    <ItemCard
                      key={item.id}
                      item={item}
                      snoozeMenuOpen={openSnoozeMenuItem === String(item.id)}
                      onToggleSnoozeMenu={() =>
                        setOpenSnoozeMenuItem((current) => (current === String(item.id) ? null : String(item.id)))
                      }
                      onSnoozeOption={(optionKey) => snoozeItem(activeTab, String(item.id), item, optionKey)}
                      onDismiss={() => updateItemState(activeTab, String(item.id), "dismissed", null)}
                      snoozeDisabledOptions={SNOOZE_OPTIONS.reduce(
                        (acc, option) => {
                          const limit = getDueDateSnoozeLimit(item);
                          acc[option.key] = limit !== null && getSnoozeTarget(option.key) > limit;
                          return acc;
                        },
                        {} as Record<SnoozeOptionKey, boolean>
                      )}
                    />
                  ))}
                </div>
              )}
            </div>

            <WorkspaceFab
              items={minimizedItems}
              open={openMinimizedPanelByTab[activeTab]}
              onToggle={() => toggleMinimizedPanel(activeTab)}
              onRestore={(itemId) => restoreFromMinimized(activeTab, itemId)}
            />
          </div>
        </div>

        <div className="space-y-6 lg:col-span-1">
          <div className="rounded-[14px] border border-zinc-200/60 bg-white/60 p-4 dark:border-zinc-800/60 dark:bg-zinc-900/35">
            <h3 className="mb-4 border-b border-zinc-200/70 pb-3 text-xs font-medium uppercase tracking-[0.2em] text-zinc-500 dark:border-zinc-800/70 dark:text-zinc-500">
              Timeline
            </h3>
            <TimelineSection groups={timelineGroups} />
          </div>

          <div className="rounded-[14px] border border-zinc-200/60 bg-white/60 p-4 dark:border-zinc-800/60 dark:bg-zinc-900/35">
            <h3 className="mb-4 border-b border-zinc-200/70 pb-3 text-xs font-medium uppercase tracking-[0.2em] text-zinc-500 dark:border-zinc-800/70 dark:text-zinc-500">
              Context
            </h3>
            <ContextFeed items={informationItems} />
          </div>
        </div>
      </div>
    </div>
  );
}
