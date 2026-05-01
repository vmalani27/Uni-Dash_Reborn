import { useState, useEffect, useCallback } from "react";
import { getAcademicDashboard } from '@/lib/api';

/* =========================
   Types (aligned to backend)
========================= */

export interface DashboardPayload {
  academic_items?: any[];
  groups?: Record<string, any[]>;
  timeline?: any[];
  focus?: any;
  banner?: any;
  [key: string]: any;
}

export interface UIDashboard {
  focus: any | null;
  sections: Record<string, any[]>;
  timeline: any[];
  banner: any | null;
}

/* =========================
   Mapping Layer (CRITICAL)
========================= */

function mapBackendToUI(data: DashboardPayload): UIDashboard {
  return {
    focus: data.focus ?? null,
    sections: data.groups ?? {},
    timeline: data.timeline ?? [],
    banner: data.banner ?? null,
  };
}

/* =========================
   Cache Layer (unchanged)
========================= */

const dashboardCache = new Map<string, DashboardPayload>();
const inFlightRequests = new Map<string, Promise<DashboardPayload>>();
const LOCAL_STORAGE_KEY = "academic_dashboard_cache";
const CACHE_KEY = "academic";

function readCachedDashboard(): DashboardPayload | null {
  if (dashboardCache.has(CACHE_KEY)) {
    return dashboardCache.get(CACHE_KEY) || null;
  }

  if (typeof window === "undefined") {
    return null;
  }

  try {
    const stored = localStorage.getItem(LOCAL_STORAGE_KEY);
    if (!stored) return null;

    const parsed = JSON.parse(stored) as DashboardPayload;
    dashboardCache.set(CACHE_KEY, parsed);
    return parsed;
  } catch {
    console.error("Failed to parse local storage cache");
    return null;
  }
}

/* =========================
   Core Hook
========================= */

function useSharedDashboardData() {
  const initialData = readCachedDashboard();
  const [data, setData] = useState<DashboardPayload | null>(initialData);
  const [isLoading, setIsLoading] = useState(!initialData);
  const [error, setError] = useState<Error | null>(null);

  const mutate = useCallback(async (background = false) => {
    if (!background) setIsLoading(true);

    try {
      let promise = inFlightRequests.get(CACHE_KEY);
      if (!promise) {
        promise = getAcademicDashboard();
        inFlightRequests.set(CACHE_KEY, promise);
      }

      const result = await promise;

      dashboardCache.set(CACHE_KEY, result);
      if (typeof window !== "undefined") {
        localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(result));
      }

      setData(result);
      setError(null);
    } catch (err) {
      if (!dashboardCache.has(CACHE_KEY)) {
        setError(err as Error);
      }
      console.error("Dashboard fetch failed:", err);
    } finally {
      setIsLoading(false);
      inFlightRequests.delete(CACHE_KEY);
    }
  }, []);

  useEffect(() => {
    void mutate(true); // SWR pattern
  }, [mutate]);

  return { data, isLoading, error, mutate };
}

/* =========================
   UI Hook (USE THIS)
========================= */

export function useDashboardData() {
  const { data, isLoading, error, mutate } = useSharedDashboardData();

  const uiData = data ? mapBackendToUI(data) : null;

  return {
    data: uiData,
    isLoading,
    error,
    mutate,
  };
}

/* =========================
   Optional (if still needed)
========================= */

export function useTimelineData() {
  const { data, isLoading, error, mutate } = useDashboardData();
  return {
    data: data?.timeline || [],
    isLoading,
    error,
    mutate,
  };
}

export function useFeedData() {
  const { data, isLoading, error, mutate } = useDashboardData();
  return {
    data: data?.sections || {},
    isLoading,
    error,
    mutate,
  };
}