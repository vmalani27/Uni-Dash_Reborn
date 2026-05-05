import type { NextConfig } from "next";

const allowedDevOrigins = [
  "localhost",
  "127.0.0.1",
  "0.0.0.0",
  "100.108.163.29",
  process.env.NEXT_DEV_ALLOWED_ORIGIN,
].filter((value): value is string => Boolean(value && value.trim()));

const nextConfig: NextConfig = {
  allowedDevOrigins,
};

export default nextConfig;
