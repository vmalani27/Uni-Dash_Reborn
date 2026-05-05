import { useState, useEffect, useCallback } from "react";

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
   Core Hook (no API calls)
========================= */

function useSharedDashboardData() {
  const [data, setData] = useState<DashboardPayload | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const mutate = useCallback(async (_background = false) => {
    setIsLoading(false);
    setData(null);
    setError(null);
  }, []);

  useEffect(() => {
    void mutate(true);
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
