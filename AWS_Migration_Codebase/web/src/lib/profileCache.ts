export const PROFILE_CACHE_KEY = "unidash:userProfile";

export function readCachedUserProfile<T = any>(): T | null {
  if (typeof window === "undefined") {
    return null;
  }

  const rawValue = window.localStorage.getItem(PROFILE_CACHE_KEY);

  if (!rawValue) {
    return null;
  }

  try {
    return JSON.parse(rawValue) as T;
  } catch {
    return null;
  }
}

export function writeCachedUserProfile(profile: unknown): void {
  if (typeof window === "undefined") {
    return;
  }

  window.localStorage.setItem(PROFILE_CACHE_KEY, JSON.stringify(profile));
}

export function clearCachedUserProfile(): void {
  if (typeof window === "undefined") {
    return;
  }

  window.localStorage.removeItem(PROFILE_CACHE_KEY);
}

export function isCompleteUserProfile(profile: any): boolean {
  if (!profile) {
    return false;
  }

  const requiredFields = [profile.full_name, profile.degree, profile.branch, profile.sid];
  const hasRequiredStrings = requiredFields.every((value) => typeof value === "string" && value.trim().length > 0);
  const admissionYear = Number(profile.admission_year);

  return hasRequiredStrings && Number.isFinite(admissionYear);
}