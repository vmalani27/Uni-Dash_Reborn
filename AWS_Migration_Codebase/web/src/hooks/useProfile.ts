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
  [key: string]: any;
}

export function useProfile() {
  const cachedProfile = readCachedUserProfile<UserProfile>();
  const [profile, setProfile] = useState<UserProfile | null>(cachedProfile);
  const [isLoading, setIsLoading] = useState(!cachedProfile);
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
    } catch (err: any) {
      if (err.status === 404) {
        setProfile(null);
        clearCachedUserProfile();
      } else {
        setError(err as Error);
      }
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void checkProfile(true);
  }, [checkProfile]);

  return { profile, isLoading, error, refetch: checkProfile };
}
