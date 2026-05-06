import { getCurrentUserIdToken } from './cognito';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8000';

export const getAuthToken = async (): Promise<string | null> => {
  return await getCurrentUserIdToken();
};

export class ApiError extends Error {
  status?: number;

  constructor(message: string, status?: number) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

export const fetchWithAuth = async (
  url: string,
  options: RequestInit = {}
): Promise<any> => {
  const token = await getAuthToken();

  if (!token) {
    throw new ApiError('Unauthorized', 401);
  }

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string> | undefined),
    Authorization: `Bearer ${token}`,
  };

  const response = await fetch(`${API_BASE_URL}${url}`, {
    ...options,
    headers,
  });

  const data = await response.json();

  if (response.status === 401) {
    throw new ApiError(data.error || 'Unauthorized', 401);
  }

  if (response.status === 404) {
    throw new ApiError(data.error || 'Not Found', 404);
  }

  if (!response.ok) {
    throw new ApiError(data.error || 'Request failed', response.status);
  }

  return data;
};

export const getUserProfile = async () => {
  return await fetchWithAuth('/user/profile', { method: 'GET' });
};

export interface ProfileInput {
  fullName: string;
  degree: string;
  branch: string;
  admissionYear: number;
  sid?: string;
}

export const createUserProfile = async (profileData: ProfileInput) => {
  return await fetchWithAuth('/user/profile', {
    method: 'POST',
    body: JSON.stringify(profileData),
  });
};

export const updateUserProfile = async (profileData: Partial<ProfileInput>) => {
  const cleaned = Object.fromEntries(
    Object.entries(profileData).filter(([, value]) => value != null)
  );

  return await fetchWithAuth('/user/profile', {
    method: 'PUT',
    body: JSON.stringify(cleaned),
  });
};
