'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { signIn, signUp, confirmSignUp } from '@/lib/cognito';
import { ApiError, getUserProfile } from '@/lib/api';

export default function Home() {
  const router = useRouter();
  const [mode, setMode] = useState<'login' | 'register' | 'verify'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [verificationCode, setVerificationCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const checkAuth = async () => {
      try {
        await getUserProfile();
        router.push('/dashboard');
      } catch (err) {
        if (err instanceof ApiError && err.status === 404) {
          router.push('/dashboard/profile');
          return;
        }

        if (err instanceof ApiError && err.status === 401) {
          return;
        }
      }
    };

    checkAuth();
  }, [router]);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await signIn(email, password);

      try {
        await getUserProfile();
        router.push('/dashboard');
      } catch (err) {
        if (err instanceof ApiError && err.status === 404) {
          router.push('/dashboard/profile');
          return;
        }

        if (err instanceof ApiError && err.status === 401) {
          router.push('/');
          return;
        }

        router.push('/dashboard');
      }
    } catch (err: any) {
      setError(err.message || 'Login failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    setLoading(true);

    try {
      await signUp(email, password);
      setMode('verify');
      setError('');
    } catch (err: any) {
      setError(err.message || 'Registration failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await confirmSignUp(email, verificationCode);
      setMode('login');
      setEmail('');
      setPassword('');
      setVerificationCode('');
      setError('');
    } catch (err: any) {
      setError(err.message || 'Verification failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <main style={{ padding: '20px', maxWidth: '400px', margin: '50px auto' }}>
      <h1>UniDash</h1>

      {error && (
        <div style={{ color: 'red', marginBottom: '10px', padding: '10px', border: '1px solid red' }}>
          {error}
        </div>
      )}

      {mode === 'login' && (
        <form onSubmit={handleLogin}>
          <h2>Login</h2>
          <div style={{ marginBottom: '15px' }}>
            <label>
              Email:
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                style={{ width: '100%', padding: '8px', marginTop: '5px' }}
              />
            </label>
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label>
              Password:
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                style={{ width: '100%', padding: '8px', marginTop: '5px' }}
              />
            </label>
          </div>
          <button type="submit" disabled={loading} style={{ width: '100%', padding: '10px' }}>
            {loading ? 'Logging in...' : 'Login'}
          </button>
          <p>
            Don't have an account?{' '}
            <button
              type="button"
              onClick={() => {
                setMode('register');
                setError('');
                setEmail('');
                setPassword('');
              }}
              style={{ color: 'blue', textDecoration: 'underline', border: 'none', cursor: 'pointer' }}
            >
              Register
            </button>
          </p>
        </form>
      )}

      {mode === 'register' && (
        <form onSubmit={handleRegister}>
          <h2>Register</h2>
          <div style={{ marginBottom: '15px' }}>
            <label>
              Email:
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                style={{ width: '100%', padding: '8px', marginTop: '5px' }}
              />
            </label>
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label>
              Password:
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                style={{ width: '100%', padding: '8px', marginTop: '5px' }}
              />
            </label>
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label>
              Confirm Password:
              <input
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
                style={{ width: '100%', padding: '8px', marginTop: '5px' }}
              />
            </label>
          </div>
          <button type="submit" disabled={loading} style={{ width: '100%', padding: '10px' }}>
            {loading ? 'Registering...' : 'Register'}
          </button>
          <p>
            Already have an account?{' '}
            <button
              type="button"
              onClick={() => {
                setMode('login');
                setError('');
                setEmail('');
                setPassword('');
                setConfirmPassword('');
              }}
              style={{ color: 'blue', textDecoration: 'underline', border: 'none', cursor: 'pointer' }}
            >
              Login
            </button>
          </p>
        </form>
      )}

      {mode === 'verify' && (
        <form onSubmit={handleVerify}>
          <h2>Verify Email</h2>
          <p>We've sent a verification code to {email}. Please enter it below:</p>
          <div style={{ marginBottom: '15px' }}>
            <label>
              Verification Code:
              <input
                type="text"
                value={verificationCode}
                onChange={(e) => setVerificationCode(e.target.value)}
                required
                style={{ width: '100%', padding: '8px', marginTop: '5px' }}
              />
            </label>
          </div>
          <button type="submit" disabled={loading} style={{ width: '100%', padding: '10px' }}>
            {loading ? 'Verifying...' : 'Verify'}
          </button>
          <p>
            <button
              type="button"
              onClick={() => {
                setMode('register');
                setVerificationCode('');
                setError('');
              }}
              style={{ color: 'blue', textDecoration: 'underline', border: 'none', cursor: 'pointer' }}
            >
              Back to Register
            </button>
          </p>
        </form>
      )}
    </main>
  );
}
