import { useState, useEffect, useCallback } from "react";
import { getUserProfile } from "@/lib/api";
import {
  clearCachedUserProfile,
  isCompleteUserProfile,
  readCachedUserProfile,
  writeCachedUserProfile,
} from "@/lib/profileCache";

export interface UserProfile {
  full_name: string;
  degree: string;
  branch: string;
  admission_year: number;
  sid: string;
  [key: string]: unknown;
}

export function useProfile() {
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const checkProfile = useCallback(async (silent = false) => {
    if (!silent) {
      setIsLoading(true);
    }

    try {
      const data = await getUserProfile();
      if (isCompleteUserProfile(data)) {
        setProfile(data);
        writeCachedUserProfile(data);
        setError(null);
      } else {
        setProfile(null);
        clearCachedUserProfile();
      }
    } catch (err: unknown) {
      const status =
        typeof err === "object" && err !== null && "status" in err
          ? (err as { status?: number }).status
          : undefined;

      if (status === 404) {
        setProfile(null);
        clearCachedUserProfile();
      } else {
        setError(err instanceof Error ? err : new Error("Failed to fetch profile"));
      }
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    // Read client cache only after mount to avoid SSR/client hydration mismatches.
    const cachedProfile = readCachedUserProfile<UserProfile>();
    if (cachedProfile && isCompleteUserProfile(cachedProfile)) {
      setProfile(cachedProfile);
      setIsLoading(false);
    } else {
      clearCachedUserProfile();
      setProfile(null);
      setIsLoading(true);
    }

    void checkProfile(true);
  }, [checkProfile]);

  return { profile, isLoading, error, refetch: checkProfile };
}
