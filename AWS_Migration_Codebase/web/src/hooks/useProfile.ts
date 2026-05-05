import { useState, useEffect, useCallback } from "react";
import { getUserProfile } from "@/lib/api";

export interface UserProfile {
  full_name: string;
  degree: string;
  branch: string;
  admission_year: number;
  sid: string;
  [key: string]: any;
}

export function useProfile() {
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const checkProfile = useCallback(async () => {
    try {
      const data = await getUserProfile();
      setProfile(data);
      setError(null);
    } catch (err: any) {
      if (err.status === 404) {
        setProfile(null);
      } else {
        setError(err as Error);
      }
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void checkProfile();
  }, [checkProfile]);

  return { profile, isLoading, error, refetch: checkProfile };
}
