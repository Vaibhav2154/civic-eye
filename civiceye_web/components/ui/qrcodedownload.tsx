"use client";
import { QRCodeCanvas, QRCodeSVG } from "qrcode.react";


export default function QrDownloadCard() {
  return (
    <div className="flex flex-col items-center mt-6 p-6 rounded-xl bg-white bg-opacity-10 backdrop-blur-md shadow-lg border border-gray-600">
      <h3 className="text-xl font-bold text-cyan-300 mb-4">📱 Scan to Download CivicEye App</h3>
      <QRCodeCanvas value="https://your-app-download-link.com" size={180} fgColor="#ffffff" bgColor="transparent" />
    </div>
  )
}