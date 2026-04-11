"use client";

import { useState } from "react";
import { useTimelineData, useFeedData } from "@/hooks/useDashboard";
import { ChevronRight, Clock, AlertCircle, BookOpen, Award } from "lucide-react";

// Types based on the backend data structure
interface SyncItem {
  id: string | number;
  title: string;
  entity_type: string;
  description?: string;
  due_date?: string;
  course_code?: string;
  location?: string;
  academic_score?: number;
}

interface TimelineGroup {
  date: string;
  items: SyncItem[];
}

// Focus Card - High priority single item at top
function FocusCard({ item }: { item: SyncItem | null }) {
  if (!item) return null;

  const getIcon = (type: string) => {
    switch (type?.toUpperCase()) {
      case "EXAM":
        return <AlertCircle className="h-5 w-5" />;
      case "ASSIGNMENT":
        return <BookOpen className="h-5 w-5" />;
      case "OPPORTUNITY":
        return <Award className="h-5 w-5" />;
      default:
        return <Clock className="h-5 w-5" />;
    }
  };

  return (
    <div className="rounded-[14px] border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-900/60 p-4 shadow-sm hover:border-zinc-300 dark:hover:border-zinc-600 transition-colors">
      <div className="flex gap-3 items-start mb-3">
        <div className="p-2 rounded-lg bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300">
          {getIcon(item.entity_type)}
        </div>
        <div className="flex-1">
          <div className="inline-block px-2 py-1 rounded-full bg-zinc-100 dark:bg-zinc-800 text-xs font-bold uppercase tracking-wide text-zinc-600 dark:text-zinc-400 mb-2">
            {item.entity_type || "Item"}
          </div>
          <h3 className="text-base font-semibold text-zinc-900 dark:text-zinc-50 leading-tight line-clamp-2">{item.title}</h3>
        </div>
      </div>

      {item.description && (
        <p className="text-sm text-zinc-600 dark:text-zinc-400 line-clamp-2 mb-3">{item.description}</p>
      )}

      <div className="flex items-center justify-between pt-3 border-t border-zinc-200 dark:border-zinc-700">
        <div className="text-xs text-zinc-500 dark:text-zinc-500 font-medium">
          {item.course_code && <span>{item.course_code}</span>}
          {item.due_date && (
            <span>
              {item.course_code && " • "}
              Due {new Date(item.due_date).toLocaleDateString(undefined, { month: "short", day: "numeric" })}
            </span>
          )}
        </div>
        {item.academic_score !== undefined && (
          <div className="text-xs font-bold text-indigo-600 dark:text-indigo-400">
            Score: {(item.academic_score * 100).toFixed(0)}%
          </div>
        )}
      </div>
    </div>
  );
}

// Bucket Tabs - Categories
const BUCKET_CATEGORIES = [
  { key: "assignments", label: "Assignments", icon: "📝" },
  { key: "exams", label: "Exams", icon: "📋" },
  { key: "opportunities", label: "Opportunities", icon: "⭐" },
  { key: "admin", label: "Announcements", icon: "📢" },
];

function BucketTabs({
  activeTab,
  setActiveTab,
  data,
}: {
  activeTab: string;
  setActiveTab: (tab: string) => void;
  data: Record<string, SyncItem[]>;
}) {
  return (
    <div className="flex gap-2 border-b border-zinc-200 dark:border-zinc-700 -mx-4 px-4">
      {BUCKET_CATEGORIES.map((cat) => {
        const count = data[cat.key]?.length || 0;
        const isActive = activeTab === cat.key;

        return (
          <button
            key={cat.key}
            onClick={() => setActiveTab(cat.key)}
            className={`flex items-center gap-2 px-3 py-3 text-sm font-semibold whitespace-nowrap rounded-t-lg border-b-2 transition-colors ${
              isActive
                ? "border-zinc-900 dark:border-zinc-100 text-zinc-900 dark:text-zinc-100"
                : "border-transparent text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-200"
            }`}
          >
            <span>{cat.icon}</span>
            <span>{cat.label}</span>
            <span className="text-xs bg-zinc-100 dark:bg-zinc-800 px-2 py-0.5 rounded-full font-medium">
              {count}
            </span>
          </button>
        );
      })}
    </div>
  );
}

// Bucket Panel - Shows items from selected tab
function BucketPanel({ items, tabKey }: { items: SyncItem[]; tabKey: string }) {
  if (!items || items.length === 0) {
    return (
      <div className="py-8 text-center text-zinc-500 dark:text-zinc-400 text-sm">
        No {BUCKET_CATEGORIES.find((c) => c.key === tabKey)?.label.toLowerCase()} yet.
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {items.map((item) => (
        <div
          key={item.id}
          className="group flex items-start gap-3 p-3 rounded-[11px] border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-900/40 hover:border-zinc-300 dark:hover:border-zinc-600 cursor-pointer transition-colors"
        >
          <div className="h-2 w-2 rounded-full bg-zinc-400 dark:bg-zinc-600 mt-1.5 flex-shrink-0" />
          <div className="flex-1 min-w-0">
            <h4 className="text-sm font-semibold text-zinc-900 dark:text-zinc-50 line-clamp-1 group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition-colors">
              {item.title}
            </h4>
            <p className="text-xs text-zinc-600 dark:text-zinc-400 mt-0.5 line-clamp-1">{item.course_code}</p>
            {item.due_date && (
              <p className="text-xs text-zinc-500 dark:text-zinc-500 mt-1">
                Due {new Date(item.due_date).toLocaleDateString(undefined, { month: "short", day: "numeric" })}
              </p>
            )}
          </div>
          <ChevronRight className="h-4 w-4 text-zinc-400 dark:text-zinc-600 flex-shrink-0 group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition-colors" />
        </div>
      ))}
    </div>
  );
}

// Vertical Sections - Horizontal scrolling card rows
function VerticalSections({ data }: { data: SyncItem[] }) {
  const grouped = BUCKET_CATEGORIES.reduce(
    (acc, cat) => {
      acc[cat.key] = data.filter((item) => item.entity_type?.toUpperCase() === cat.key.toUpperCase().slice(0, -1));
      return acc;
    },
    {} as Record<string, SyncItem[]>
  );

  return (
    <div className="space-y-6 -mx-4 px-4">
      {BUCKET_CATEGORIES.map((cat) => {
        const items = grouped[cat.key] || [];
        if (items.length === 0) return null;

        return (
          <div key={cat.key}>
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-bold uppercase tracking-wider text-zinc-600 dark:text-zinc-400">
                {cat.label} <span className="font-normal text-zinc-500 dark:text-zinc-500 ml-2">{items.length}</span>
              </h3>
            </div>
            <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-hide">
              {items.map((item) => (
                <div
                  key={item.id}
                  className="flex-shrink-0 w-72 rounded-[11px] border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-900/50 p-3 hover:border-zinc-300 dark:hover:border-zinc-600 cursor-pointer transition-colors"
                >
                  <div className="flex items-center gap-2 mb-2">
                    <span className="px-2 py-1 rounded-full bg-zinc-100 dark:bg-zinc-800 text-xs font-bold uppercase tracking-wide text-zinc-600 dark:text-zinc-400">
                      {item.entity_type}
                    </span>
                  </div>
                  <h4 className="text-sm font-semibold text-zinc-900 dark:text-zinc-50 line-clamp-2 mb-1">{item.title}</h4>
                  {item.description && (
                    <p className="text-xs text-zinc-600 dark:text-zinc-400 line-clamp-1 mb-3">{item.description}</p>
                  )}
                  <div className="flex items-center justify-between text-xs text-zinc-500 dark:text-zinc-500">
                    <span>{item.course_code}</span>
                    {item.due_date && (
                      <span>{new Date(item.due_date).toLocaleDateString(undefined, { month: "short", day: "numeric" })}</span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}

// Timeline - Compact version for right panel
function TimelineSection() {
  const { data, isLoading, error } = useTimelineData();

  if (isLoading) {
    return (
      <div className="space-y-2">
        {[1, 2, 3].map((i) => (
          <div key={i} className="h-12 bg-zinc-200 dark:bg-zinc-700 rounded-md animate-pulse" />
        ))}
      </div>
    );
  }

  if (error) return <div className="text-xs text-red-500">Failed to load timeline</div>;
  if (!data || data.length === 0) return <div className="text-xs text-zinc-500">No upcoming events</div>;

  return (
    <div className="space-y-3">
      {(data as TimelineGroup[]).map((dayGroup, idx) => (
        <div key={idx}>
          <div className="text-xs font-bold uppercase tracking-wider text-zinc-600 dark:text-zinc-400 mb-2 flex items-center gap-2">
            <div className="h-0.5 w-1.5 rounded-full bg-indigo-500" />
            {dayGroup.date}
          </div>
          <div className="space-y-1 ml-3">
            {dayGroup.items?.slice(0, 3).map((item) => (
              <div
                key={item.id}
                className="text-xs text-zinc-600 dark:text-zinc-400 p-2 rounded-md hover:bg-zinc-100 dark:hover:bg-zinc-800 cursor-pointer transition-colors line-clamp-1"
              >
                {item.title}
              </div>
            ))}
            {dayGroup.items?.length > 3 && (
              <div className="text-[10px] text-zinc-500 dark:text-zinc-500 p-2 font-medium">
                +{dayGroup.items.length - 3} more
              </div>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}

// Context Feed - Information items
function ContextFeed() {
  const { data, isLoading, error } = useFeedData();

  if (isLoading) {
    return (
      <div className="space-y-2">
        {[1, 2].map((i) => (
          <div key={i} className="h-10 bg-zinc-200 dark:bg-zinc-700 rounded-md animate-pulse" />
        ))}
      </div>
    );
  }

  if (error) return <div className="text-xs text-red-500">Failed to load context</div>;

  const informationItems = (data as SyncItem[])
    .filter((item) => item.entity_type?.toUpperCase() === "INFORMATION")
    .slice(0, 5);

  if (informationItems.length === 0) return <div className="text-xs text-zinc-500">No recent information</div>;

  return (
    <div className="space-y-2">
      {informationItems.map((item) => (
        <div
          key={item.id}
          className="text-xs p-2 rounded-md border border-zinc-200 dark:border-zinc-700 hover:border-zinc-300 dark:hover:border-zinc-600 cursor-pointer transition-colors group"
        >
          <div className="flex items-start gap-2">
            <div className="h-1.5 w-1.5 rounded-full bg-zinc-400 dark:bg-zinc-600 mt-1 flex-shrink-0" />
            <div className="flex-1 min-w-0">
              <p className="font-medium text-zinc-900 dark:text-zinc-100 line-clamp-1 group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition-colors">
                {item.title}
              </p>
              {item.description && <p className="text-zinc-600 dark:text-zinc-400 line-clamp-1 mt-0.5">{item.description}</p>}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

export default function DashboardPage() {
  const { data: feedData, isLoading: feedLoading } = useFeedData();
  const typedFeedData = feedData as SyncItem[] | null;
  const allItems = typedFeedData || [];
  const focusItem = allItems[0] || null;

  const groupedData: Record<string, SyncItem[]> = {
    assignments: allItems.filter((item) => item.entity_type?.toUpperCase() === "ASSIGNMENT"),
    exams: allItems.filter((item) => item.entity_type?.toUpperCase() === "EXAM"),
    opportunities: allItems.filter((item) => item.entity_type?.toUpperCase() === "OPPORTUNITY"),
    admin: allItems.filter((item) => item.entity_type?.toUpperCase() === "ACADEMIC_ADMIN"),
  };

  const [activeTab, setActiveTab] = useState("assignments");

  if (feedLoading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="h-96 bg-zinc-200 dark:bg-zinc-700 rounded-lg animate-pulse" />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* LEFT COLUMN - 70% */}
        <div className="lg:col-span-2 space-y-6">
          {/* Focus Card */}
          <FocusCard item={focusItem} />

          {/* Bucket Tabs & Panel */}
          <div className="rounded-[14px] border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-900/50 overflow-hidden">
            <div className="px-4 pt-4">
              <BucketTabs activeTab={activeTab} setActiveTab={setActiveTab} data={groupedData} />
            </div>
            <div className="p-4">
              <BucketPanel items={groupedData[activeTab] || []} tabKey={activeTab} />
            </div>
          </div>

          {/* Vertical Sections */}
          <div className="space-y-4">
            <VerticalSections data={allItems} />
          </div>
        </div>

        {/* RIGHT COLUMN - 30% */}
        <div className="lg:col-span-1 space-y-6">
          {/* Timeline Panel */}
          <div className="rounded-[14px] border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-900/50 p-4">
            <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-600 dark:text-zinc-400 mb-4 pb-3 border-b border-zinc-200 dark:border-zinc-700">
              📅 Timeline
            </h3>
            <TimelineSection />
          </div>

          {/* Context Feed Panel */}
          <div className="rounded-[14px] border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-900/50 p-4">
            <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-600 dark:text-zinc-400 mb-4 pb-3 border-b border-zinc-200 dark:border-zinc-700">
              ℹ️ Context
            </h3>
            <ContextFeed />
          </div>
        </div>
      </div>
    </div>
  );
}
