import { NextRequest, NextResponse } from "next/server";
import { initAdmin } from "@/lib/firebase/firebase-admin";
import * as admin from "firebase-admin";

export async function POST(request: NextRequest) {
  try {
    const { token } = await request.json();
    initAdmin();

    const expiresIn = 60 * 60 * 24 * 5 * 1000; // 5 days

    const sessionCookie = await admin.auth().createSessionCookie(token, {
      expiresIn,
    });

    const options = {
      name: "session",
      value: sessionCookie,
      maxAge: expiresIn / 1000,
      httpOnly: true,
      secure: process.env.NODE_NODE !== "development",
      path: "/",
    };

    const response = NextResponse.json({ status: "success" }, { status: 200 });
    response.cookies.set(options);
    return response;
  } catch (error) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
}
