import { useState, useEffect, useCallback } from "react";
import { getAcademicDashboard } from '@/lib/api';

export interface DashboardPayload {
  timeline?: unknown[];
  academic_items?: unknown[];
  [key: string]: unknown;
}

// Global in-memory cache
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
    if (!stored) {
      return null;
    }

    const parsed = JSON.parse(stored) as DashboardPayload;
    dashboardCache.set(CACHE_KEY, parsed);
    return parsed;
  } catch {
    console.error("Failed to parse local storage cache");
    return null;
  }
}

function useSharedDashboardData() {
  const initialData = readCachedDashboard();
  const [data, setData] = useState<DashboardPayload | null>(initialData);
  const [isLoading, setIsLoading] = useState(!initialData);
  const [error, setError] = useState<Error | null>(null);

  const mutate = useCallback(async (background = false) => {
    if (!background) {
      setIsLoading(true);
    }

    try {
      let promise = inFlightRequests.get(CACHE_KEY);
      if (!promise) {
        promise = getAcademicDashboard();
        inFlightRequests.set(CACHE_KEY, promise);
      }

      const result = await promise;

      // Update caches
      dashboardCache.set(CACHE_KEY, result);
      if (typeof window !== "undefined") {
        localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(result));
      }

      setData(result);
      setError(null);
    } catch (err) {
      // If we have cached data, suppress UI disruption but log the error
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
    // Always background revalidate (Stale-While-Revalidate pattern) on mount.
    void mutate(true);
  }, [mutate]);

  return { data, isLoading, error, mutate };
}

// In the future, these can fetch separate endpoints. For now, they share the academic dashboard endpoint
// but give us the component-level separation we want.
export function useTimelineData() {
  const { data, isLoading, error, mutate } = useSharedDashboardData();
  return {
    data: data?.timeline || [],
    isLoading,
    error,
    mutate
  };
}

export function useFeedData() {
  const { data, isLoading, error, mutate } = useSharedDashboardData();
  return {
    data: data?.academic_items || [],
    isLoading,
    error,
    mutate
  };
}

export function useDashboardData() {
  return useSharedDashboardData();
}
