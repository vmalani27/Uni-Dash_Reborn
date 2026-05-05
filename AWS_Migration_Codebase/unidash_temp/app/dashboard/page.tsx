'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ApiError, getUserProfile } from '@/lib/api';

interface UserProfile {
  full_name?: string;
  email?: string;
  degree?: string;
  branch?: string;
  admission_year?: number;
  sid?: string;
}

export default function DashboardPage() {
  const router = useRouter();
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        const data = await getUserProfile();
        setProfile(data);
      } catch (err) {
        console.error('Error fetching profile:', err);
        if (err instanceof ApiError && err.status === 404) {
          router.push('/dashboard/profile');
          return;
        }

        if (err instanceof ApiError && err.status === 401) {
          router.push('/');
          return;
        }

        setError('Failed to load profile');
      } finally {
        setLoading(false);
      }
    };

    fetchProfile();
  }, []);

  if (loading) {
    return <div>Loading...</div>;
  }

  return (
    <div>
      <h1>Dashboard</h1>

      {error && (
        <div style={{ color: 'red', marginBottom: '10px', padding: '10px', border: '1px solid red' }}>
          {error}
        </div>
      )}

      {profile ? (
        <pre>{JSON.stringify(profile, null, 2)}</pre>
      ) : (
        <div style={{ marginTop: '20px', padding: '15px', border: '1px solid #ddd' }}>
          <p>No profile found. Please complete your profile.</p>
        </div>
      )}
    </div>
  );
}
