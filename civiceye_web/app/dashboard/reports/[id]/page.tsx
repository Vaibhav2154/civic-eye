'use client';

import { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { supabase } from '../../../../lib/supabaseClient';
import dynamic from 'next/dynamic';

const ReportMap = dynamic(() => import('../../../../components/ReportMap'), { ssr: false });

interface CrimeReport {
  id: string;
  title: string;
  category: string;
  description: string;
  city: string;
  state: string;
  country: string;
  latitude: number;
  longitude: number;
  reporter_id: string;
  status: string;
  is_anonymous: boolean;
  submitted_at: string;
}

export default function ReportDetail() {
  const params = useParams();
  const reportId = params.id;
  const [report, setReport] = useState<CrimeReport | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    fetchReport();
  }, [reportId]);

  

  async function fetchReport() {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('reports')
        .select('*')
        .eq('id', reportId)
        .single();

      if (error) throw error;
      if (data) setReport(data as CrimeReport);
    } catch (error) {
      console.error('Error fetching report:', error);
    } finally {
      setLoading(false);
    }
  }

  async function updateReportStatus(status: string) {
    try {
      const { error } = await supabase
        .from('reports')
        .update({ status })
        .eq('id', reportId);

      if (error) throw error;
      if (report) setReport({ ...report, status });
    } catch (error) {
      console.error('Error updating report status:', error);
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background text-foreground">
        <p className="text-xl font-semibold text-secondary">Loading report details...</p>
      </div>
    );
  }

  if (!report) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background text-foreground">
        <div className="text-center p-6 bg-destructive text-destructive-foreground rounded-xl">
          <p className="text-lg">Report not found.</p>
          <button
            onClick={() => router.push('/dashboard/view-files')}
            className="mt-4 px-4 py-2 bg-primary text-primary-foreground rounded transition"
          >
            Back to Reports
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col min-h-screen bg-background text-foreground">
      <header className="w-full py-6 px-6 md:px-10 border-b bg-background border-border sticky top-0 z-10">
        <div className="flex items-center">
          <button
            onClick={() => router.push('/dashboard/view-files')}
            className="mr-4 text-primary hover:underline"
          >
            ← Back
          </button>
          <h1 className="text-2xl font-bold text-secondary">Report Details</h1>
        </div>
      </header>

      <main className="flex-grow flex justify-center px-4 md:px-10 py-10">
        <div className="w-full max-w-5xl bg-card border border-border rounded-2xl shadow-lg p-8 space-y-10">
          <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
            <h2 className="text-3xl font-semibold tracking-tight text-secondary">{report.title}</h2>
            <StatusBadge status={report.status} />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <p><span className="font-medium">Category:</span> {report.category}</p>
              <p><span className="font-medium">Location:</span> {report.city}, {report.state}, {report.country}</p>
              <p><span className="font-medium">Date Submitted:</span> {new Date(report.submitted_at).toLocaleDateString()}</p>
              <p><span className="font-medium">Anonymous:</span> {report.is_anonymous ? 'Yes' : 'No'}</p>
            </div>
            <div className="space-y-2">
              <p><span className="font-medium">Coordinates:</span> {report.latitude}, {report.longitude}</p>
              {!report.is_anonymous && (
                <p><span className="font-medium">Reporter ID:</span> {report.reporter_id}</p>
              )}
            </div>
          </div>

          <div>
            <h3 className="text-xl font-semibold mb-2">Description</h3>
            <div className="p-4 bg-accent text-accent-foreground rounded-xl whitespace-pre-wrap">
              {report.description}
            </div>
          </div>

          <div>
            <h3 className="text-xl font-semibold mb-2">Map Location</h3>
            <div className="overflow-hidden rounded-xl h-80">
              <ReportMap lat={Number(report.latitude)} lng={Number(report.longitude)} />

            </div>
          </div>

          {report.status === 'pending' && (
            <div className="flex flex-col sm:flex-row gap-4 justify-end">
              <button
                onClick={() => updateReportStatus('accepted')}
                className="px-6 py-3 rounded-md bg-emerald-600 hover:bg-emerald-700 text-white"
              >
                Accept Report
              </button>
              <button
                onClick={() => updateReportStatus('rejected')}
                className="px-6 py-3 rounded-md bg-red-600 hover:bg-red-700 text-white"
              >
                Reject Report
              </button>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    pending: 'bg-amber-500',
    accepted: 'bg-emerald-500',
    rejected: 'bg-red-500',
    under_review: 'bg-amber-500',
    investigating: 'bg-emerald-500',
  };

  const bgColor = colors[status] || 'bg-gray-500';

  return (
    <span className={`px-4 py-1 rounded-full text-xs font-semibold text-white ${bgColor}`}>
      {status.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())}
    </span>
  );
}