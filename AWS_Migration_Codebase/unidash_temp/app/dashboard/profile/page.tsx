'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ApiError, getUserProfile, createUserProfile, updateUserProfile } from '@/lib/api';

interface UserProfile {
  full_name?: string;
  email?: string;
  degree?: string;
  branch?: string;
  admission_year?: number;
  sid?: string;
}

export default function ProfilePage() {
  const router = useRouter();
  const [formData, setFormData] = useState<UserProfile>({
    full_name: '',
    degree: '',
    branch: '',
    admission_year: new Date().getFullYear(),
    sid: '',
  });
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [mode, setMode] = useState<'create' | 'edit'>('create');

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        const data = await getUserProfile();
        if (data) {
          setFormData(data);
          setMode('edit');
        } else {
          setMode('create');
        }
      } catch (err) {
        console.error('Error fetching profile:', err);
        if (err instanceof ApiError && err.status === 401) {
          router.push('/');
          return;
        }

        setMode('create');
      } finally {
        setLoading(false);
      }
    };

    fetchProfile();
  }, []);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    
    setFormData((prev) => ({
      ...prev,
      [name]: name === 'admission_year' ? parseInt(value, 10) : value,
    }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSubmitting(true);

    try {
      if (mode === 'create') {
        await createUserProfile(formData);
      } else {
        await updateUserProfile(formData);
      }
      router.push('/dashboard');
    } catch (err: any) {
      setError(err.message || 'Failed to save profile. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return <div>Loading...</div>;
  }

  return (
    <div>
      <h1>Profile {mode === 'edit' ? 'Edit' : 'Creation'}</h1>

      {error && (
        <div style={{ color: 'red', marginBottom: '10px', padding: '10px', border: '1px solid red' }}>
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} style={{ maxWidth: '500px' }}>
        <div style={{ marginBottom: '15px' }}>
          <label>
            Full Name:
            <input
              type="text"
              name="full_name"
              value={formData.full_name || ''}
              onChange={handleChange}
              required
              style={{ width: '100%', padding: '8px', marginTop: '5px' }}
            />
          </label>
        </div>

        <div style={{ marginBottom: '15px' }}>
          <label>
            Degree:
            <input
              type="text"
              name="degree"
              value={formData.degree || ''}
              onChange={handleChange}
              required
              style={{ width: '100%', padding: '8px', marginTop: '5px' }}
            />
          </label>
        </div>

        <div style={{ marginBottom: '15px' }}>
          <label>
            Branch:
            <input
              type="text"
              name="branch"
              value={formData.branch || ''}
              onChange={handleChange}
              required
              style={{ width: '100%', padding: '8px', marginTop: '5px' }}
            />
          </label>
        </div>

        <div style={{ marginBottom: '15px' }}>
          <label>
            Admission Year:
            <input
              type="number"
              name="admission_year"
              value={formData.admission_year || new Date().getFullYear()}
              onChange={handleChange}
              required
              style={{ width: '100%', padding: '8px', marginTop: '5px' }}
            />
          </label>
        </div>

        <div style={{ marginBottom: '15px' }}>
          <label>
            Student ID:
            <input
              type="text"
              name="sid"
              value={formData.sid || ''}
              onChange={handleChange}
              required
              style={{ width: '100%', padding: '8px', marginTop: '5px' }}
            />
          </label>
        </div>

        <button
          type="submit"
          disabled={submitting}
          style={{ width: '100%', padding: '10px', backgroundColor: '#007bff', color: 'white', border: 'none', cursor: 'pointer' }}
        >
          {submitting ? 'Saving...' : mode === 'create' ? 'Create Profile' : 'Update Profile'}
        </button>
      </form>
    </div>
  );
}
