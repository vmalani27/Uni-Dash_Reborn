"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { getAuthToken, getUserProfile, createUserProfile } from "@/lib/api";
import { BadgeCheck, BookOpen, GraduationCap, IdCard, Loader2, Sparkles } from "lucide-react";

const FIELD_STYLE =
  "w-full rounded-[var(--radius-tile)] border border-[var(--color-outline)] bg-[var(--color-surface)] px-4 py-3 text-sm text-[var(--color-on-surface)] placeholder:text-[color:rgba(31,29,26,0.45)] shadow-[0_1px_0_rgba(0,0,0,0.02)] transition-colors focus:border-[var(--color-primary)] focus:ring-2 focus:ring-[color:rgba(103,80,164,0.18)] dark:placeholder:text-[color:rgba(244,239,244,0.42)]";

const LabeledField = ({
  label,
  icon: Icon,
  children,
}: {
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  children: React.ReactNode;
}) => (
  <div className="space-y-2">
    <label className="flex items-center gap-2 text-xs font-medium uppercase tracking-[0.18em] text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">
      <Icon className="h-3.5 w-3.5" />
      {label}
    </label>
    {children}
  </div>
);

export default function ProfileSetupPage() {
  const router = useRouter();
  const [formData, setFormData] = useState({
    full_name: "",
    degree: "",
    branch: "",
    admission_year: new Date().getFullYear().toString(),
    sid: "",
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const token = await getAuthToken();
        if (!token) {
          router.replace("/");
          return;
        }
      } catch {
        router.replace("/");
      }
    };

    const checkExistingProfile = async () => {
      try {
        await getUserProfile();
        router.replace("/dashboard");
      } catch (err: any) {
        if (err.status !== 404) {
          router.replace("/");
        }
      }
    };

    void checkAuth();
    void checkExistingProfile();
  }, [router]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    setError("");
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setIsSubmitting(true);

    const year = parseInt(formData.admission_year, 10);

    if (isNaN(year)) {
      setError("Invalid admission year");
      setIsSubmitting(false);
      return;
    }

    try {
      await createUserProfile({
        full_name: formData.full_name.trim(),
        degree: formData.degree.trim(),
        branch: formData.branch.trim(),
        admission_year: year,
        sid: formData.sid.trim(),
      });

      router.replace("/dashboard");
    } catch (err: any) {
      if (err.status === 401) {
        router.replace("/");
        return;
      }

      if (err.status === 409) {
        setError("Profile already exists.");
        return;
      }

      if (err.status === 400) {
        setError("Invalid input. Please check your details.");
        return;
      }

      setError("Failed to create profile. Please try again.");
      console.error(err);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden px-4 py-8 text-[var(--color-on-surface)]">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(103,80,164,0.14),transparent_36%),radial-gradient(circle_at_bottom_right,rgba(103,80,164,0.08),transparent_32%)]" />

      <section className="relative w-full max-w-[880px] overflow-hidden rounded-[var(--radius-card)] border border-[var(--color-outline)] bg-[var(--color-surface)] shadow-[0_18px_60px_rgba(31,29,26,0.12)] dark:shadow-[0_18px_60px_rgba(0,0,0,0.32)]">
        <div className="grid md:grid-cols-[1.05fr_1.25fr]">
          <aside className="flex flex-col justify-between gap-8 border-b border-[var(--color-outline)] bg-[color:rgba(103,80,164,0.05)] p-6 sm:p-8 md:border-b-0 md:border-r">
            <div className="space-y-6">
              <div className="inline-flex items-center gap-2 rounded-full border border-[color:rgba(103,80,164,0.2)] bg-[color:rgba(103,80,164,0.08)] px-3 py-1 text-xs font-medium uppercase tracking-[0.18em] text-[var(--color-primary)]">
                <Sparkles className="h-3.5 w-3.5" />
                Profile setup
              </div>

              <div className="space-y-3">
                <h1 className="text-2xl font-[var(--font-weight-title)] tracking-tight text-[var(--color-on-surface)] sm:text-[2rem]">
                  Complete your profile
                </h1>
                <p className="max-w-sm text-sm leading-6 text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">
                  Add your academic details once so UniDash can shape the dashboard around your student life.
                </p>
              </div>

              <div className="space-y-3">
                <div className="flex items-center gap-3 rounded-[var(--radius-tile)] border border-[var(--color-outline)] bg-[var(--color-surface)] px-4 py-3">
                  <BadgeCheck className="h-5 w-5 text-[var(--color-primary)]" />
                  <div>
                    <p className="text-sm font-[var(--font-weight-value)] text-[var(--color-on-surface)]">Secure account sync</p>
                    <p className="text-xs text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">Cognito-authenticated profile creation</p>
                  </div>
                </div>

                <div className="flex items-center gap-3 rounded-[var(--radius-tile)] border border-[var(--color-outline)] bg-[var(--color-surface)] px-4 py-3">
                  <BookOpen className="h-5 w-5 text-[var(--color-primary)]" />
                  <div>
                    <p className="text-sm font-[var(--font-weight-value)] text-[var(--color-on-surface)]">Personalized schedule</p>
                    <p className="text-xs text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">Built from your degree and branch</p>
                  </div>
                </div>
              </div>
            </div>

            <p className="text-xs text-[color:rgba(31,29,26,0.45)] dark:text-[color:rgba(244,239,244,0.45)]">
              © 2026 UniDash
            </p>
          </aside>

          <div className="p-6 sm:p-8">
            {error && (
              <div className="mb-5 rounded-[var(--radius-tile)] border border-[color:rgba(186,26,26,0.2)] bg-[color:rgba(186,26,26,0.08)] p-4">
                <p className="text-sm text-[color:#8f1d1d] dark:text-[color:#ffb4ab]">{error}</p>
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-4">
              <LabeledField label="Full name" icon={IdCard}>
                <input
                  type="text"
                  name="full_name"
                  value={formData.full_name}
                  onChange={handleChange}
                  className={FIELD_STYLE}
                  placeholder="John Doe"
                  required
                />
              </LabeledField>

              <LabeledField label="Student ID" icon={IdCard}>
                <input
                  type="text"
                  name="sid"
                  value={formData.sid}
                  onChange={handleChange}
                  className={FIELD_STYLE}
                  placeholder="UNI-2025-XXXXX"
                  required
                />
              </LabeledField>

              <LabeledField label="Degree" icon={GraduationCap}>
                <input
                  type="text"
                  name="degree"
                  value={formData.degree}
                  onChange={handleChange}
                  className={FIELD_STYLE}
                  placeholder="B.Tech, B.Sc, M.Tech, etc."
                  required
                />
              </LabeledField>

              <LabeledField label="Branch" icon={BookOpen}>
                <input
                  type="text"
                  name="branch"
                  value={formData.branch}
                  onChange={handleChange}
                  className={FIELD_STYLE}
                  placeholder="Computer Science, Electronics, etc."
                  required
                />
              </LabeledField>

              <LabeledField label="Admission year" icon={GraduationCap}>
                <input
                  type="number"
                  name="admission_year"
                  value={formData.admission_year}
                  onChange={handleChange}
                  className={FIELD_STYLE}
                  placeholder="2024"
                  required
                />
              </LabeledField>

              <button
                type="submit"
                disabled={isSubmitting}
                className="inline-flex w-full items-center justify-center gap-2 rounded-[var(--radius-button)] bg-[var(--color-primary)] px-4 py-3 text-sm font-[var(--font-weight-value)] text-[var(--color-on-primary)] transition-transform transition-colors hover:translate-y-[-1px] hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-[var(--opacity-disabled)]"
              >
                {isSubmitting ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
                {isSubmitting ? "Saving profile..." : "Save profile"}
              </button>
            </form>
          </div>
        </div>
      </section>
    </main>
  );
}
