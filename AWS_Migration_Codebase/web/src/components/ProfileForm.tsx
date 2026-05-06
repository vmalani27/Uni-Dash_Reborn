"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getAuthToken, getUserProfile, createUserProfile, updateUserProfile } from "@/lib/api";
import { BadgeCheck, BookOpen, GraduationCap, IdCard, Loader2, Sparkles } from "lucide-react";

export interface ProfileData {
  full_name: string;
  degree: string;
  branch: string;
  admission_year: number | string;
  sid: string;
}

export type ProfileMode = "setup" | "edit";

export interface ProfileFormProps {
  mode: ProfileMode;
  initialData?: ProfileData | null;
  onSuccess?: () => void;
}

const FIELD_STYLE =
  "w-full rounded-[var(--radius-tile)] border border-[var(--color-outline)] bg-[var(--color-surface)] px-4 py-3 text-sm text-[var(--color-on-surface)] placeholder:text-[color:rgba(31,29,26,0.45)] shadow-[0_1px_0_rgba(0,0,0,0.02)] transition-colors focus:border-[var(--color-primary)] focus:ring-2 focus:ring-[color:rgba(103,80,164,0.18)] dark:placeholder:text-[color:rgba(244,239,244,0.42)]";

const DISABLED_FIELD_STYLE =
  "opacity-60 bg-[color:rgba(31,29,26,0.04)] cursor-not-allowed dark:bg-[color:rgba(244,239,244,0.02)]";

export default function ProfileForm({ mode, initialData = null, onSuccess }: ProfileFormProps) {
  const router = useRouter();
  const [formData, setFormData] = useState<ProfileData>({
    full_name: "",
    degree: "",
    branch: "",
    admission_year: new Date().getFullYear().toString(),
    sid: "",
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [isLoadingProfile, setIsLoadingProfile] = useState<boolean>(mode === "edit");

  useEffect(() => {
    let isMounted = true;

    const checkAuthAndLoad = async () => {
      try {
        const token = await getAuthToken();
        if (!token) {
          router.replace("/");
          return;
        }

        if (mode === "edit") {
          setIsLoadingProfile(true);
          if (initialData) {
            setFormData(initialData);
            setIsLoadingProfile(false);
            return;
          }

          try {
            const resp: any = await getUserProfile();
            if (!isMounted) return;
            setFormData({
              full_name: resp.full_name || "",
              degree: resp.degree || "",
              branch: resp.branch || "",
              admission_year: resp.admission_year || new Date().getFullYear().toString(),
              sid: resp.sid || "",
            });
          } catch (err: any) {
            if (err.status === 401) {
              router.replace("/");
              return;
            }
            // If profile not found on edit, route back to setup
            if (err.status === 404) {
              router.replace("/profile-setup");
              return;
            }
          } finally {
            if (isMounted) setIsLoadingProfile(false);
          }
        }
      } catch (err) {
        router.replace("/");
      }
    };

    void checkAuthAndLoad();

    return () => {
      isMounted = false;
    };
  }, [mode, initialData, router]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value } as ProfileData));
    setError("");
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setIsSubmitting(true);

    const year = parseInt(String(formData.admission_year), 10);

    if (isNaN(year)) {
      setError("Invalid admission year");
      setIsSubmitting(false);
      return;
    }

    try {
      if (mode === "setup") {
        await createUserProfile({
          fullName: formData.full_name.trim(),
          degree: formData.degree.trim(),
          branch: formData.branch.trim(),
          admissionYear: year,
          sid: formData.sid.trim(),
        });

        if (onSuccess) {
          onSuccess();
        } else {
          router.replace("/dashboard");
        }
      } else {
        // edit mode - only branch and admission year are editable
        await updateUserProfile({
          branch: formData.branch.trim(),
          admissionYear: year,
        });

        if (onSuccess) {
          onSuccess();
        } else {
          router.replace("/profile");
        }
      }
    } catch (err: any) {
      if (err.status === 401) {
        router.replace("/");
        return;
      }

      if (err.status === 409 && mode === "setup") {
        setError("Profile already exists.");
        return;
      }

      if (err.status === 400) {
        setError("Invalid input. Please check your details.");
        return;
      }

      setError("Failed to save profile. Please try again.");
      console.error(err);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="p-6 sm:p-8">
      {error && (
        <div className="mb-5 rounded-[var(--radius-tile)] border border-[color:rgba(186,26,26,0.2)] bg-[color:rgba(186,26,26,0.08)] p-4">
          <p className="text-sm text-[color:#8f1d1d] dark:text-[color:#ffb4ab]">{error}</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="space-y-2">
          <label className="flex items-center gap-2 text-xs font-medium uppercase tracking-[0.18em] text-[color:rgba(31,29,26,0.68)] dark:text-[color:rgba(244,239,244,0.68)]">
            {mode === "setup" ? (
              <>
                <Sparkles className="h-3.5 w-3.5" />
                Profile setup
              </>
            ) : (
              <>
                <BadgeCheck className="h-3.5 w-3.5" />
                Edit profile
              </>
            )}
          </label>
        </div>

        <div>
          <div className="space-y-4">
            <div>
              <input
                type="text"
                name="full_name"
                value={formData.full_name}
                onChange={handleChange}
                className={`${FIELD_STYLE} ${mode === "edit" ? DISABLED_FIELD_STYLE : ""}`}
                placeholder="Full name"
                required
                disabled={isLoadingProfile || mode === "edit"}
              />
            </div>

            <div>
              <input
                type="text"
                name="sid"
                value={formData.sid}
                onChange={handleChange}
                className={`${FIELD_STYLE} ${mode === "edit" ? DISABLED_FIELD_STYLE : ""}`}
                placeholder="Student ID"
                required
                disabled={isLoadingProfile || mode === "edit"}
              />
            </div>

            <div>
              <input
                type="text"
                name="degree"
                value={formData.degree}
                onChange={handleChange}
                className={`${FIELD_STYLE} ${mode === "edit" ? DISABLED_FIELD_STYLE : ""}`}
                placeholder="Degree"
                required
                disabled={isLoadingProfile || mode === "edit"}
              />
            </div>

            <div>
              <input
                type="text"
                name="branch"
                value={formData.branch}
                onChange={handleChange}
                className={FIELD_STYLE}
                placeholder="Branch"
                required
                disabled={isLoadingProfile}
              />
            </div>

            <div>
              <input
                type="number"
                name="admission_year"
                value={String(formData.admission_year)}
                onChange={handleChange}
                className={FIELD_STYLE}
                placeholder="Admission year"
                required
                disabled={isLoadingProfile}
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={isSubmitting}
            className="inline-flex w-full items-center justify-center gap-2 rounded-[var(--radius-button)] bg-[var(--color-primary)] px-4 py-3 text-sm font-[var(--font-weight-value)] text-[var(--color-on-primary)] transition-transform transition-colors hover:translate-y-[-1px] hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-[var(--opacity-disabled)]"
          >
            {isSubmitting ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
            {isSubmitting ? (mode === "setup" ? "Saving profile..." : "Updating profile...") : (mode === "setup" ? "Save profile" : "Save changes")}
          </button>
        </div>
      </form>
    </div>
  );
}
