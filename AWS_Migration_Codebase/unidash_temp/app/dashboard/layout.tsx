'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { isUserLoggedIn, signOut } from '@/lib/cognito';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [isLoggedIn, setIsLoggedIn] = useState(false);

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const loggedIn = await isUserLoggedIn();
        if (!loggedIn) {
          router.push('/');
        } else {
          setIsLoggedIn(true);
        }
      } catch (error) {
        console.error('Auth check failed:', error);
        router.push('/');
      } finally {
        setLoading(false);
      }
    };

    checkAuth();
  }, [router]);

  const handleLogout = async () => {
    try {
      signOut();
      router.push('/');
    } catch (error) {
      console.error('Logout failed:', error);
    }
  };

  if (loading) {
    return <div >Loading...</div>;
  }

  if (!isLoggedIn) {
    return null;
  }

  return (
    <>
      <nav style={{ padding: '15px', borderBottom: '1px solid #ddd' }}>
        <div style={{ maxWidth: '1000px', margin: '0 auto', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h2 style={{ margin: 0 }}>UniDash</h2>
          <div style={{ display: 'flex', gap: '20px', alignItems: 'center' }}>
            <Link href="/dashboard" style={{ textDecoration: 'none', color: '#000' }}>
              Dashboard
            </Link>
            <Link href="/dashboard/profile" style={{ textDecoration: 'none', color: '#000' }}>
              Profile
            </Link>
            <button
              onClick={handleLogout}
              style={{
                padding: '8px 16px',
                backgroundColor: '#ff4444',
                color: 'white',
                border: 'none',
                cursor: 'pointer',
              }}
            >
              Logout
            </button>
          </div>
        </div>
      </nav>
      <main style={{ maxWidth: '1000px', margin: '0 auto', padding: '20px' }}>
        {children}
      </main>
    </>
  );
}
