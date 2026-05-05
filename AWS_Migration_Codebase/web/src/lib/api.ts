import { getCurrentUserIdToken } from './cognito';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8000';

export const getAuthToken = async (): Promise<string | null> => {
  return await getCurrentUserIdToken();
};

interface FetchOptions extends RequestInit {
  headers?: Record<string, string>;
}

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
  options: FetchOptions = {}
): Promise<any> => {
  const token = await getAuthToken();

  if (!token) {
    throw new ApiError('Unauthorized', 401);
  }

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...options.headers,
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const response = await fetch(`${API_BASE_URL}${url}`, {
    ...options,
    headers,
  });

  if (response.status === 401) {
    throw new ApiError('Unauthorized', 401);
  }

  if (response.status === 404) {
    throw new ApiError('Not Found', 404);
  }

  return await response.json();
};

export const getUserProfile = async () => {
  try {
    return await fetchWithAuth('/user/profile');
  } catch (error) {
    const status = error instanceof ApiError ? error.status : (error as any)?.status;

    if (status !== 404 && status !== 401) {
      console.error('Error fetching user profile:', error);
    }

    throw error;
  }
};

export const createUserProfile = async (profileData: any) => {
  try {
    return await fetchWithAuth('/user/profile', {
      method: 'POST',
      body: JSON.stringify(profileData),
    });
  } catch (error) {
    console.error('Error creating user profile:', error);
    throw error;
  }
};

export const updateUserProfile = async (profileData: any) => {
  try {
    return await fetchWithAuth('/user/profile', {
      method: 'PUT',
      body: JSON.stringify(profileData),
    });
  } catch (error) {
    console.error('Error updating user profile:', error);
    throw error;
  }
};
