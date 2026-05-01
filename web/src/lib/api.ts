import { auth } from "@/lib/firebase/firebase";

const BASE_URL = process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1:8000";

// Replicates Flutter's api_services.dart behavior
export async function fetchWithAuth(endpoint: string, options: RequestInit = {}) {
  const user = auth.currentUser;
  
  if (!user) {
    throw new Error("No Firebase user is currently authenticated.");
  }

  const doRequest = async (forceRefreshToken: boolean) => {
    const token = await user.getIdToken(forceRefreshToken);
    const headers = new Headers(options.headers);
    headers.set("Content-Type", "application/json");
    headers.set("Authorization", `Bearer ${token}`);
    headers.set("ngrok-skip-browser-warning", "true");

    return fetch(`${BASE_URL}${endpoint}`, {
      ...options,
      headers,
    });
  };

  let response = await doRequest(false);

  // Recovery path for stale ID tokens after sign-in/session restore.
  if (response.status === 401) {
    response = await doRequest(true);
  }

  if (!response.ok) {
    throw new Error(`API Error: ${response.status} ${await response.text()}`);
  }

  return response.json();
}

/**
 * Endpoint specific fetchers
 */
export async function getAcademicDashboard() {
  return fetchWithAuth("/api/dashboard/");
}

export async function getUserProfile() {
  return fetchWithAuth("/user/profile");
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
