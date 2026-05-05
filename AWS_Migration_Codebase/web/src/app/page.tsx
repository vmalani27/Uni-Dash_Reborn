"use client";

import { useState } from "react";
import { Sparkles, ArrowRight, Eye, EyeOff, MoveRight } from "lucide-react";

export default function AuthPage() {
  const [isLogin, setIsLogin] = useState(true);
  const [isVerified, setIsVerified] = useState(false);
  const [isVerifying, setIsVerifying] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [verificationCode, setVerificationCode] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showPasswords, setShowPasswords] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    
    try {
      // TODO: Implement actual auth logic
      if (!isLogin && password !== confirmPassword) {
        throw new Error("Passwords do not match");
      }
      
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      if (!isLogin) {
        // After registration, show verification step
        setIsVerifying(true);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "An error occurred");
    } finally {
      setLoading(false);
    }
  };

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    
    try {
      // TODO: Implement actual verification logic
      await new Promise(resolve => setTimeout(resolve, 1000));
      setIsVerified(true);
      setIsVerifying(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Verification failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="app-shell flex items-center justify-center px-4 py-6 sm:px-6 sm:py-8 lg:px-8">
      <section className="w-full max-w-[1100px] overflow-hidden app-surface-strong">
        <div className="grid min-h-[min(860px,calc(100vh-3rem))] lg:grid-cols-2">
          {/* Left Panel - Features */}
          <aside className="hidden flex-col justify-between border-r border-[var(--color-outline)] p-10 lg:flex">
            <div className="space-y-10">
              <div className="space-y-4">
                <h2 className="app-heading text-3xl leading-tight xl:text-4xl">
                  Manage your academic life in one place.
                </h2>
                <p className="max-w-lg text-sm leading-6 app-muted">
                  All your classes, assignments, and events unified into one calm, structured space.
                </p>
              </div>

              <ul className="space-y-4">
                <li className="flex items-start gap-3">
                  <ArrowRight className="mt-0.5 h-4 w-4 flex-shrink-0 text-[var(--color-primary)]" />
                  <span className="text-sm text-[var(--color-on-surface)]">
                    Track assignments and deadlines
                  </span>
                </li>
                <li className="flex items-start gap-3">
                  <ArrowRight className="mt-0.5 h-4 w-4 flex-shrink-0 text-[var(--color-primary)]" />
                  <span className="text-sm text-[var(--color-on-surface)]">
                    Get notified about important updates
                  </span>
                </li>
                <li className="flex items-start gap-3">
                  <ArrowRight className="mt-0.5 h-4 w-4 flex-shrink-0 text-[var(--color-primary)]" />
                  <span className="text-sm text-[var(--color-on-surface)]">
                    Stay on top of your schedule
                  </span>
                </li>
              </ul>
            </div>

            <p className="text-xs text-[color:rgba(31,29,26,0.45)] dark:text-[color:rgba(244,239,244,0.45)]">
              © 2026 UniDash
            </p>
          </aside>

          {/* Right Panel - Auth Form */}
          <div className="flex items-center justify-center p-5 sm:p-8 lg:p-10">
            <div className="w-full max-w-lg">
              <div className="app-surface p-6 sm:p-8">
                <div className="mb-8">
                  <h1 className="mb-3 text-2xl font-semibold tracking-tight text-[var(--color-on-surface)]">
                    {isLogin ? "Sign in" : "Create account"}
                  </h1>
                  <p className="text-sm app-muted">
                    {isLogin 
                      ? "Enter your academic email to continue" 
                      : "Set up your UniDash account"}
                  </p>
                </div>

                {/* Tab Switcher */}
                <div className="mb-8 flex gap-1 border-b border-[var(--color-outline)]">
                  <button
                    type="button"
                    onClick={() => {
                      setIsLogin(true);
                      setError("");
                      setConfirmPassword("");
                    }}
                    className={`px-1 py-3 text-xs font-medium uppercase tracking-wider transition-colors ${
                      isLogin
                        ? "border-b-2 border-[var(--color-primary)] text-[var(--color-on-surface)]"
                        : "text-[color:rgba(31,29,26,0.58)] dark:text-[color:rgba(244,239,244,0.58)]"
                    }`}
                  >
                    Sign In
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setIsLogin(false);
                      setError("");
                      setConfirmPassword("");
                    }}
                    className={`px-1 py-3 text-xs font-medium uppercase tracking-wider transition-colors ${
                      !isLogin
                        ? "border-b-2 border-[var(--color-primary)] text-[var(--color-on-surface)]"
                        : "text-[color:rgba(31,29,26,0.58)] dark:text-[color:rgba(244,239,244,0.58)]"
                    }`}
                  >
                    Register
                  </button>
                </div>

                {/* Error Message */}
                {error && (
                  <div className="mb-6 rounded-[var(--radius-tile)] border border-[color:rgba(186,26,26,0.2)] bg-[color:rgba(186,26,26,0.08)] p-4">
                    <p className="text-sm text-[color:#8f1d1d] dark:text-[color:#ffb4ab]">
                      {error}
                    </p>
                  </div>
                )}

                {/* Verified State */}
                {isVerified ? (
                  <div className="flex flex-col items-center gap-5 text-center">
                    <div className="text-lg font-semibold text-[var(--color-on-surface)]">
                      Account verified successfully
                    </div>
                    <div className="text-sm app-muted">
                      You can now log in to your account.
                    </div>
                    <button
                      onClick={() => {
                        setIsVerified(false);
                        setIsLogin(true);
                        setPassword("");
                        setConfirmPassword("");
                        setVerificationCode("");
                      }}
                      className="mt-3 app-button-primary px-4 py-2.5 text-sm"
                    >
                      Go to Login
                    </button>
                  </div>
                ) : isVerifying ? (
                  /* Verification Form */
                  <form onSubmit={handleVerify} className="flex flex-col gap-5">
                    <div className="flex flex-col gap-2">
                      <label className="app-label">Enter Verification Code</label>
                      <input
                        type="text"
                        value={verificationCode}
                        onChange={(e) => setVerificationCode(e.target.value)}
                        className="app-input"
                        placeholder="Enter OTP"
                        required
                        maxLength={6}
                      />
                    </div>
                    <button
                      type="submit"
                      disabled={loading}
                      className="mt-3 app-button-primary px-4 py-2.5 text-sm"
                    >
                      {loading ? "Verifying..." : "Verify Account"}
                    </button>
                  </form>
                ) : (
                  /* Auth Form (Login/Register) */
                  <form onSubmit={handleSubmit} className="flex flex-col gap-5">
                    {/* Email Field */}
                    <div className="flex flex-col gap-2">
                      <label className="app-label">Email</label>
                      <input
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        className="app-input"
                        placeholder="your.name@university.edu"
                        required
                        pattern=".*@.*\.edu$"
                        title="Please use your academic email address"
                      />
                    </div>

                    {/* Password Field */}
                    <div className="flex flex-col gap-2">
                      <label className="app-label">Password</label>
                      <div className="relative">
                        <input
                          type={
                            isLogin
                              ? showPassword
                                ? "text"
                                : "password"
                              : showPasswords
                              ? "text"
                              : "password"
                          }
                          value={password}
                          onChange={(e) => setPassword(e.target.value)}
                          className="app-input pr-10"
                          placeholder="Enter your password"
                          required
                          minLength={8}
                        />
                        {isLogin && (
                          <button
                            type="button"
                            onClick={() => setShowPassword(!showPassword)}
                            className="absolute right-3 top-1/2 -translate-y-1/2 text-[color:rgba(31,29,26,0.58)] hover:text-[var(--color-on-surface)] transition-colors"
                            aria-label={showPassword ? "Hide password" : "Show password"}
                          >
                            {showPassword ? (
                              <EyeOff size={18} />
                            ) : (
                              <Eye size={18} />
                            )}
                          </button>
                        )}
                      </div>
                    </div>

                    {/* Confirm Password (Register only) */}
                    {!isLogin && (
                      <>
                        <div className="flex flex-col gap-2">
                          <label className="app-label">Confirm Password</label>
                          <input
                            type={showPasswords ? "text" : "password"}
                            value={confirmPassword}
                            onChange={(e) => setConfirmPassword(e.target.value)}
                            className="app-input"
                            placeholder="Confirm your password"
                            required
                            minLength={8}
                          />
                        </div>
                        <button
                          type="button"
                          onClick={() => setShowPasswords(!showPasswords)}
                          className="mx-auto text-xs text-[color:rgba(31,29,26,0.68)] hover:text-[var(--color-on-surface)] dark:text-[color:rgba(244,239,244,0.68)] transition-colors"
                        >
                          {showPasswords ? "Hide passwords" : "Show passwords"}
                        </button>
                      </>
                    )}

                    {/* Submit Button */}
                    <button
                      type="submit"
                      disabled={loading}
                      className="group mt-3 app-button-primary px-4 py-2.5 text-sm disabled:cursor-not-allowed disabled:opacity-70 flex items-center justify-center gap-2"
                    >
                      {loading ? (
                        isLogin ? (
                          "Signing in..."
                        ) : (
                          "Creating account..."
                        )
                      ) : isLogin ? (
                        "Sign In"
                      ) : (
                        "Register"
                      )}
                      {!loading && (
                        <MoveRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
                      )}
                    </button>
                  </form>
                )}

                {/* Forgot Password Link (Login only) */}
                {isLogin && !isVerifying && !isVerified && (
                  <div className="mt-6 text-center">
                    <p className="text-xs app-muted">
                      Forgot your password?{" "}
                      <a
                        href="#"
                        className="font-medium text-[var(--color-on-surface)] hover:text-[var(--color-primary)] transition-colors"
                      >
                        Reset it
                      </a>
                    </p>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}