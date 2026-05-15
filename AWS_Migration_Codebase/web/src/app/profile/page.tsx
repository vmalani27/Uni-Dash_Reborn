"use client";

import { useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  ArrowLeft,
  BadgeCheck,
  BookOpen,
  CalendarDays,
  GraduationCap,
  IdCard,
  Pencil,
  LogOut,
  Mail,
  Building2,
} from "lucide-react";
import { getAuthToken } from "@/lib/api";
import { signOut } from "@/lib/cognito";
import { getGoogleConnectUrl } from "@/lib/cognito-oauth";
import { useProfile } from "@/hooks/useProfile";
import { isCompleteUserProfile } from "@/lib/profileCache";

const CARD_STYLE =
  "rounded-[var(--radius-card)] border border-[var(--color-outline)] bg-[var(--color-surface)] p-5 shadow-[0_1px_0_rgba(0,0,0,0.02)]";

function ProfileStat({
  icon: Icon,
  label,
  value,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-start gap-3 rounded-[var(--radius-tile)] border border-[var(--color-outline)] bg-[color:rgba(103,80,164,0.04)] p-4">
      <Icon className="mt-0.5 h-5 w-5 text-[var(--color-primary)]" />
      <div className="min-w-0">
        <p className="text-[11px] font-[var(--font-weight-label)] uppercase tracking-[0.18em] text-[color:rgba(31,29,26,0.58)] dark:text-[color:rgba(244,239,244,0.58)]">
          {label}
        </p>
        <p className="mt-1 truncate text-sm font-[var(--font-weight-value)] text-[var(--color-on-surface)]">
          {value}
        </p>
      </div>
    </div>
  );
}

export default function ProfilePage() {
  const router = useRouter();
  const { profile, isLoading, error } = useProfile();

  useEffect(() => {
    if (!isLoading && !isCompleteUserProfile(profile)) {
      router.replace("/profile-setup?mode=setup");
    }
  }, [isLoading, profile, router]);

  useEffect(() => {
    const verifyAuth = async () => {
      try {
        const token = await getAuthToken();
        if (!token) {
          router.replace("/");
        }
      } catch {
        router.replace("/");
      }
    };

    void verifyAuth();
  }, [router]);

  useEffect(() => {
    if ((error as any)?.status === 401) {
      router.replace("/");
    }
  }, [error, router]);

  const handleLogout = () => {
    signOut();
    router.replace("/");
  };

  const handleConnectGoogle = async () => {
    const token = await getAuthToken();
    if (!token) {
      router.replace("/");
      return;
    }

    try {
      const state = globalThis.crypto?.randomUUID?.() ?? String(Date.now());
      localStorage.setItem("cognito_oauth_state", state);
      const url = getGoogleConnectUrl(state);
      window.location.href = url;
    } catch {
      const url = getGoogleConnectUrl();
      window.location.href = url;
    }
  };

  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center px-4 py-8">
        <p className="text-sm text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">
          Loading profile...
        </p>
      </main>
    );
  }

  if (!profile) {
    return null;
  }

  // Calculate current semester based on admission year (simplified logic)
  const getCurrentSemester = (admissionYear: number | null): string => {
    if (!admissionYear) return "Not provided";
    const currentYear = new Date().getFullYear();
    const currentMonth = new Date().getMonth(); // 0 = Jan, 6 = July
    const academicYear = currentMonth >= 6 ? currentYear : currentYear - 1;
    const yearsElapsed = academicYear - admissionYear;
    
    if (yearsElapsed < 0) return "1";
    if (yearsElapsed >= 4) return "8"; // Cap at 8 semesters for 4-year degree
    
    const semester = yearsElapsed * 2 + (currentMonth >= 6 ? 2 : 1);
    return String(Math.min(semester, 8));
  };

  return (
    <main className="min-h-screen px-4 py-6 sm:px-6 sm:py-8">
      <div className="mx-auto w-full max-w-5xl space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between gap-4">
          <Link
            href="/dashboard"
            className="inline-flex items-center gap-2 text-sm font-medium text-[color:rgba(31,29,26,0.72)] transition-colors hover:text-[var(--color-on-surface)] dark:text-[color:rgba(244,239,244,0.72)]"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to dashboard
          </Link>

          <div className="flex items-center gap-2">
            <Link
              href="/profile-setup?mode=edit"
              className="inline-flex items-center gap-2 rounded-[var(--radius-button)] border border-[var(--color-outline)] bg-[var(--color-surface)] px-4 py-2.5 text-sm font-[var(--font-weight-value)] text-[var(--color-on-surface)] hover:bg-[color:rgba(103,80,164,0.06)] transition-colors"
            >
              <Pencil className="h-4 w-4" />
              Edit profile
            </Link>
            <button
              onClick={handleLogout}
              className="inline-flex items-center gap-2 rounded-[var(--radius-button)] border border-[color:rgba(186,26,26,0.2)] bg-[color:rgba(186,26,26,0.06)] px-4 py-2.5 text-sm font-[var(--font-weight-value)] text-[color:#8f1d1d] hover:bg-[color:rgba(186,26,26,0.12)] transition-colors dark:text-[color:#ffb4ab]"
            >
              <LogOut className="h-4 w-4" />
              Logout
            </button>
          </div>
        </div>

        {/* Main Content Grid */}
        <section className="grid gap-6 lg:grid-cols-[1.2fr_0.8fr]">
          {/* Left: Academic Profile */}
          <div className={CARD_STYLE}>
            <div className="flex items-start gap-4">
              <div className="flex h-14 w-14 items-center justify-center rounded-full bg-[color:rgba(103,80,164,0.12)] text-lg font-[var(--font-weight-title)] text-[var(--color-primary)]">
                {profile.full_name
                  .split(" ")
                  .map((part) => part[0])
                  .slice(0, 2)
                  .join("")
                  .toUpperCase()}
              </div>

              <div className="min-w-0 flex-1">
                <div className="inline-flex items-center gap-2 rounded-full border border-[color:rgba(103,80,164,0.18)] bg-[color:rgba(103,80,164,0.08)] px-3 py-1 text-xs font-medium uppercase tracking-[0.18em] text-[var(--color-primary)]">
                  <BadgeCheck className="h-3.5 w-3.5" />
                  Active profile
                </div>
                <h1 className="mt-4 text-3xl font-[var(--font-weight-title)] tracking-tight text-[var(--color-on-surface)]">
                  {profile.full_name}
                </h1>
                <p className="mt-2 flex items-center gap-2 text-sm text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">
                  <Mail className="h-4 w-4 flex-shrink-0" />
                  <span className="truncate">{profile.email || "No email provided"}</span>
                </p>
              </div>
            </div>

            <div className="mt-6 grid gap-4 sm:grid-cols-2">
              <ProfileStat icon={IdCard} label="Student ID" value={profile.sid || "Not provided"} />
              <ProfileStat icon={GraduationCap} label="Degree" value={profile.degree || "Not provided"} />
              <ProfileStat icon={BookOpen} label="Branch" value={profile.branch || "Not provided"} />
              <ProfileStat 
                icon={CalendarDays} 
                label="Admission year" 
                value={profile.admission_year ? String(profile.admission_year) : "Not provided"} 
              />
              <ProfileStat 
                icon={Building2} 
                label="Current semester" 
                value={getCurrentSemester(profile.admission_year)} 
              />
            </div>
          </div>

          {/* Right: Account & Connections */}
          <div className="space-y-4">
            {/* Connected Accounts */}
            <div className={CARD_STYLE}>
              <p className="text-xs font-[var(--font-weight-label)] uppercase tracking-[0.18em] text-[color:rgba(31,29,26,0.58)] dark:text-[color:rgba(244,239,244,0.58)]">
                Connected accounts
              </p>
              <div className="mt-4 space-y-3">
                <div className="flex items-start gap-3 rounded-[var(--radius-tile)] border border-[var(--color-outline)] bg-[color:rgba(103,80,164,0.04)] p-4">
                  <div className="flex h-8 w-8 items-center justify-center rounded-full bg-[color:rgba(219,68,55,0.12)]">
                    <Mail className="h-4 w-4 text-[color:#db4437]" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-[var(--font-weight-value)] text-[var(--color-on-surface)]">
                      Gmail
                    </p>
                    <p className="mt-0.5 truncate text-xs text-[color:rgba(31,29,26,0.58)] dark:text-[color:rgba(244,239,244,0.58)]">
                      {profile.email || "Not connected"}
                    </p>
                    {profile.oauth_connected ? (
                      <span className="mt-2 inline-flex items-center gap-1 text-[11px] font-medium text-[color:rgba(34,139,34,0.9)]">
                        <BadgeCheck className="h-3 w-3" />
                        Connected
                      </span>
                    ) : (
                      <button
                        onClick={() => {
                          void handleConnectGoogle();
                        }}
                        className="mt-2 inline-flex items-center gap-1 text-[11px] font-medium text-[var(--color-primary)] hover:text-[color:rgba(103,80,164,0.8)] transition-colors"
                      >
                        Connect account
                      </button>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Quick Actions */}
            <div className={CARD_STYLE}>
              <p className="text-xs font-[var(--font-weight-label)] uppercase tracking-[0.18em] text-[color:rgba(31,29,26,0.58)] dark:text-[color:rgba(244,239,244,0.58)]">
                Quick actions
              </p>
              <div className="mt-4 space-y-2">
                <button
                  onClick={handleLogout}
                  className="w-full inline-flex items-center justify-center gap-2 rounded-[var(--radius-button)] border border-[color:rgba(186,26,26,0.2)] bg-[color:rgba(186,26,26,0.06)] px-4 py-2.5 text-sm font-[var(--font-weight-value)] text-[color:#8f1d1d] hover:bg-[color:rgba(186,26,26,0.12)] transition-colors dark:text-[color:#ffb4ab]"
                >
                  <LogOut className="h-4 w-4" />
                  Sign out
                </button>
              </div>
            </div>

            {/* Profile Info Helper */}
            <div className={CARD_STYLE}>
              <p className="text-sm text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">
                Your academic details are synced with your university records. 
                Contact administration to update official information.
              </p>
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}