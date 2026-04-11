import { auth } from "@/lib/firebase/firebase";

const BASE_URL = process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1:8000";

// Replicates Flutter's api_services.dart behavior
export async function fetchWithAuth(endpoint: string, options: RequestInit = {}) {
  const user = auth.currentUser;
  
  if (!user) {
    throw new Error("No Firebase user is currently authenticated.");
  }

  const token = await user.getIdToken();

  const headers = new Headers(options.headers);
  headers.set("Content-Type", "application/json");
  headers.set("Authorization", `Bearer ${token}`);
  headers.set("ngrok-skip-browser-warning", "true");

  const response = await fetch(`${BASE_URL}${endpoint}`, {
    ...options,
    headers,
  });

  if (!response.ok) {
    throw new Error(`API Error: ${response.status} ${await response.text()}`);
  }

  return response.json();
}

/**
 * Endpoint specific fetchers
 */
export async function getDashboard() {
  return fetchWithAuth("/api/dashboard/");
}

export async function getUserProfile() {
  return fetchWithAuth("/user/profile");
}

export async function getAcademicDashboard() {
  return fetchWithAuth("/notifications/academic/dashboard");
}

export async function triggerIncrementalSync() {
  return fetchWithAuth("/gmail/sync/incremental", {
    method: "POST",
  });
}

export async function markItemDone(id: string) {
  return fetchWithAuth(`/notifications/academic/${id}/mark-done`, {
    method: "POST",
  });
}

export async function dismissItem(id: string) {
  return fetchWithAuth(`/notifications/academic/${id}/dismiss`, {
    method: "POST",
  });
}
