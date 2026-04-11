"use client";

import { useState } from "react";
import { signInWithEmailAndPassword, createUserWithEmailAndPassword } from "firebase/auth";
import { auth } from "@/lib/firebase/firebase";
import { getUserProfile } from "@/lib/api";
import { useRouter } from "next/navigation";
import { MoveRight, ArrowRight } from "lucide-react";

export default function LoginPage() {
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const router = useRouter();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email, password);
      // Initialize or fetch the backend user representation immediately
      await getUserProfile();
      router.push("/dashboard");
    } catch (error) {
      setError("Failed to login. Please check your credentials.");
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    
    if (password !== confirmPassword) {
      setError("Passwords do not match.");
      return;
    }
    
    if (password.length < 6) {
      setError("Password must be at least 6 characters.");
      return;
    }

    setLoading(true);
    try {
      await createUserWithEmailAndPassword(auth, email, password);
      // Create user record in backend database and retrieve status
      await getUserProfile();
      router.push("/dashboard");
    } catch (error) {
      setError("Failed to create account. Email may already be in use.");
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    if (isLogin) {
      await handleLogin(e);
    } else {
      await handleRegister(e);
    }
  };

  return (
    <main className="flex min-h-screen bg-zinc-50 dark:bg-zinc-950">
      <div className="flex w-full">
        {/* Left Side - Minimal Branding & Value (~60%) */}
        <div className="hidden w-3/5 flex-col justify-between border-r border-zinc-200/50 px-16 py-12 dark:border-zinc-800/50 lg:flex">
          <div>
            {/* Simple minimal logo */}
            <div className="mb-16">
              <div className="inline-block rounded border border-zinc-300 px-2.5 py-1.5 dark:border-zinc-700">
                <p className="text-lg font-semibold text-zinc-900 dark:text-zinc-100">U</p>
              </div>
            </div>
            
            {/* Product positioning */}
            <div className="space-y-10">
              <div>
                <h2 className="mb-4 text-xl font-semibold tracking-tight text-zinc-900 dark:text-zinc-100">
                  Manage your academic life in one place.
                </h2>
                <p className="text-sm text-zinc-600 dark:text-zinc-400">
                  All your classes, assignments, and events—unified and organized.
                </p>
              </div>
              
              <ul className="space-y-5">
                <li className="flex items-start gap-3">
                  <ArrowRight className="mt-0.5 h-4 w-4 flex-shrink-0 text-zinc-400 dark:text-zinc-600" />
                  <span className="text-sm text-zinc-700 dark:text-zinc-300">Track assignments and deadlines</span>
                </li>
                <li className="flex items-start gap-3">
                  <ArrowRight className="mt-0.5 h-4 w-4 flex-shrink-0 text-zinc-400 dark:text-zinc-600" />
                  <span className="text-sm text-zinc-700 dark:text-zinc-300">Get notified about important updates</span>
                </li>
                <li className="flex items-start gap-3">
                  <ArrowRight className="mt-0.5 h-4 w-4 flex-shrink-0 text-zinc-400 dark:text-zinc-600" />
                  <span className="text-sm text-zinc-700 dark:text-zinc-300">Stay on top of your schedule</span>
                </li>
              </ul>
            </div>
          </div>
          
          <p className="text-xs text-zinc-500 dark:text-zinc-500">© 2026 UniDash</p>
        </div>

        {/* Right Side - Auth Card (~40%) */}
        <div className="col-span-3 flex w-full items-center justify-center p-6 md:w-2/5 md:p-8 lg:w-2/5 lg:p-0 lg:pr-12">
          <div className="w-full max-w-sm">
            <div className="rounded-[14px] border border-zinc-200/60 bg-white/50 p-8 dark:border-zinc-800/60 dark:bg-zinc-900/30 sm:p-8">
            <div className="mb-8">
              <h1 className="mb-3 text-2xl font-semibold tracking-tight text-zinc-900 dark:text-zinc-100">
                {isLogin ? "Sign in" : "Create account"}
              </h1>
              <p className="text-sm text-zinc-600 dark:text-zinc-400">
                {isLogin ? "Enter your academic email to continue" : "Set up your UniDash account"}
              </p>
            </div>

            {/* Toggle Buttons - subtle, minimal */}
            <div className="mb-8 flex gap-1 border-b border-zinc-200 dark:border-zinc-800">
              <button
                type="button"
                onClick={() => {
                  setIsLogin(true);
                  setError("");
                  setConfirmPassword("");
                }}
                className={`px-1 py-3 text-xs font-medium uppercase tracking-wider transition-colors ${
                  isLogin
                    ? "border-b-2 border-zinc-900 text-zinc-900 dark:border-zinc-100 dark:text-zinc-100"
                    : "text-zinc-500 dark:text-zinc-400"
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
                    ? "border-b-2 border-zinc-900 text-zinc-900 dark:border-zinc-100 dark:text-zinc-100"
                    : "text-zinc-500 dark:text-zinc-400"
                }`}
              >
                Register
              </button>
            </div>

            {/* Error Message */}
            {error && (
              <div className="mb-6 rounded-lg border border-red-200 bg-red-50/50 p-4 dark:border-red-900 dark:bg-red-950/30">
                <p className="text-sm text-red-700 dark:text-red-200">{error}</p>
              </div>
            )}

            {/* Form */}
            <form onSubmit={handleSubmit} className="flex flex-col gap-5">
              <div className="flex flex-col gap-2">
                <label className="text-xs font-medium uppercase tracking-wide text-zinc-700 dark:text-zinc-300">Email</label>
                <input 
                  type="email" 
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="rounded-lg border border-zinc-300 bg-white px-3 py-2.5 text-sm text-zinc-900 placeholder:text-zinc-400 focus:border-zinc-900 focus:outline-none focus:ring-1 focus:ring-zinc-900 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100 dark:placeholder:text-zinc-500 dark:focus:border-zinc-100 dark:focus:ring-zinc-100"
                  placeholder="your.name@university.edu"
                  required 
                />
              </div>

              <div className="flex flex-col gap-2">
                <label className="text-xs font-medium uppercase tracking-wide text-zinc-700 dark:text-zinc-300">Password</label>
                <input 
                  type="password" 
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="rounded-lg border border-zinc-300 bg-white px-3 py-2.5 text-sm text-zinc-900 placeholder:text-zinc-400 focus:border-zinc-900 focus:outline-none focus:ring-1 focus:ring-zinc-900 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100 dark:placeholder:text-zinc-500 dark:focus:border-zinc-100 dark:focus:ring-zinc-100"
                  placeholder={isLogin ? "Enter password" : "Min 6 characters"}
                  required 
                />
              </div>

              {!isLogin && (
                <div className="flex flex-col gap-2">
                  <label className="text-xs font-medium uppercase tracking-wide text-zinc-700 dark:text-zinc-300">Confirm Password</label>
                  <input 
                    type="password" 
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    className="rounded-lg border border-zinc-300 bg-white px-3 py-2.5 text-sm text-zinc-900 placeholder:text-zinc-400 focus:border-zinc-900 focus:outline-none focus:ring-1 focus:ring-zinc-900 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100 dark:placeholder:text-zinc-500 dark:focus:border-zinc-100 dark:focus:ring-zinc-100"
                    placeholder="Confirm your password"
                    required 
                  />
                </div>
              )}

              <button 
                type="submit" 
                disabled={loading}
                className="group mt-3 flex items-center justify-center gap-2 rounded-lg bg-zinc-900 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-800 disabled:opacity-50 disabled:cursor-not-allowed dark:bg-zinc-100 dark:text-zinc-900 dark:hover:bg-zinc-200"
              >
                {loading ? (isLogin ? "Signing in..." : "Creating account...") : (isLogin ? "Sign In" : "Register")}
                {!loading && <MoveRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />}
              </button>
            </form>

              {isLogin && (
                <div className="mt-6 text-center">
                  <p className="text-xs text-zinc-500 dark:text-zinc-400">
                    Forgot your password?{" "}
                    <a href="#" className="font-medium text-zinc-900 hover:text-zinc-700 dark:text-zinc-100 dark:hover:text-zinc-300">
                      Reset it
                    </a>
                  </p>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </main>
  );
}
