// mailer.js
import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.ADMIN_EMAIL,
    pass: process.env.ADMIN_EMAIL_PASS,
  },
});

console.log(process.env.ADMIN_EMAIL, process.env.ADMIN_EMAIL_PASS);

export async function sendReportEmail(report) {
  const mailOptions = {
    from: `"CivicEye Alerts" <${process.env.ADMIN_EMAIL}>`,
    to: process.env.ADMIN_NOTIFY_EMAIL,
    subject: '🚨 New Report Submitted',
    html: `
      <h3>New Report</h3>
      <p><strong>Title:</strong> ${report.title}</p>
      <p><strong>Description:</strong> ${report.description}</p>
      <p><strong>Location:</strong> ${report.city}, ${report.state}, ${report.country}</p>
      <p><strong>Category:</strong> ${report.category}</p>
      <p><strong>Submitted At:</strong> ${report.submitted_at}</p>
    `,
  };

  await transporter.sendMail(mailOptions);
}
