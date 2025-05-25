import { NextRequest, NextResponse } from 'next/server';
import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS, // App password for Gmail
  },
});

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    console.log("📦 Request Body:", body);

    const { to, subject, text } = body;

    if (!to || !subject || !text) {
      return NextResponse.json(
        { error: "Missing required fields: to, subject, text" },
        { status: 400 }
      );
    }

    await transporter.sendMail({
      from: process.env.EMAIL_USER,
      to: Array.isArray(to) ? to : [to],
      subject,
      text,
    });

    return NextResponse.json({ success: true, message: "Email sent successfully" });

  } catch (error) {
    console.error("❌ Error in /api/send-email:", error);
    return NextResponse.json({ error: "Failed to send email" }, { status: 500 });
  }
}
