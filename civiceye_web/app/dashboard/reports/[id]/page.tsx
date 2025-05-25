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
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-secondary mx-auto mb-4"></div>
          <p className="text-xl font-semibold text-secondary">Loading report details...</p>
        </div>
      </div>
    );
  }

  if (!report) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background text-foreground">
        <div className="text-center p-8 bg-card border border-border rounded-xl shadow-xl backdrop-blur-sm">
          <div className="text-destructive text-4xl mb-4">⚠️</div>
          <p className="text-xl font-semibold text-foreground mb-4">Report not found.</p>
          <button
            onClick={() => router.push('/dashboard/view-files')}
            className="px-6 py-3 bg-primary hover:bg-primary/90 text-primary-foreground rounded-lg transition-all duration-200 font-medium shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
          >
            Back to Reports
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col min-h-screen bg-background text-foreground">
      <header className="w-full py-6 px-6 md:px-10 border-b bg-card/50 border-border sticky top-0 z-10 backdrop-blur-sm">
        <div className="flex items-center justify-between">
          <div className="flex items-center">
            <button
              onClick={() => router.push('/dashboard/view-files')}
              className="mr-4 text-secondary hover:text-secondary/80 transition-colors duration-200 flex items-center gap-2 group"
            >
              <span className="transform group-hover:-translate-x-1 transition-transform duration-200">←</span>
              Back
            </button>
            <h1 className="text-2xl font-bold text-foreground">Report Details</h1>
          </div>
          <button
            onClick={() => router.push(`/dashboard/reports/${reportId}/evidence`)}
            className="px-4 py-2 bg-primary hover:bg-primary/90 text-primary-foreground rounded-lg transition-all duration-200 font-medium shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 flex items-center gap-2"
          >
            <span>📁</span>
            View Evidence
          </button>
        </div>
      </header>

      <main className="flex-grow flex justify-center px-4 md:px-10 py-10">
        <div className="w-full max-w-5xl bg-card border border-border rounded-2xl shadow-xl p-8 space-y-10 backdrop-blur-sm">
          <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
            <h2 className="text-3xl font-bold tracking-tight text-foreground bg-gradient-to-r from-foreground to-muted-foreground bg-clip-text">
              {report.title}
            </h2>
            <StatusBadge status={report.status} />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            <div className="space-y-4">
              <InfoItem label="Category" value={report.category} />
              <InfoItem label="Location" value={`${report.city}, ${report.state}, ${report.country}`} />
              <InfoItem label="Date Submitted" value={new Date(report.submitted_at).toLocaleDateString()} />
              <InfoItem label="Anonymous" value={report.is_anonymous ? 'Yes' : 'No'} />
            </div>
            <div className="space-y-4">
              <InfoItem label="Coordinates" value={`${report.latitude}, ${report.longitude}`} />
              {!report.is_anonymous && (
                <InfoItem label="Reporter ID" value={report.reporter_id} />
              )}
            </div>
          </div>

          <div>
            <h3 className="text-xl font-semibold mb-4 text-foreground">Description</h3>
            <div className="p-6 bg-accent/20 border border-border rounded-xl whitespace-pre-wrap text-foreground leading-relaxed">
              {report.description}
            </div>
          </div>

          <div>
            <h3 className="text-xl font-semibold mb-4 text-foreground">Map Location</h3>
            <div className="overflow-hidden rounded-xl h-80 shadow-lg border border-border">
              <ReportMap lat={Number(report.latitude)} lng={Number(report.longitude)} />
            </div>
          </div>

          <div className="flex flex-col sm:flex-row gap-4 justify-between items-center pt-6 border-t border-border">
            <button
              onClick={() => router.push(`/dashboard/reports/${reportId}/evidence`)}
              className="px-8 py-3 bg-primary hover:bg-primary/90 text-primary-foreground rounded-lg font-medium transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 flex items-center gap-3"
            >
              <span className="text-lg">📁</span>
              <span>View Evidence Collection</span>
            </button>

            {report.status === 'pending' && (
              <div className="flex flex-col sm:flex-row gap-4">
                <button
                  onClick={() => updateReportStatus('accepted')}
                  className="px-6 py-3 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white font-medium transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
                >
                  Accept Report
                </button>
                <button
                  onClick={() => updateReportStatus('rejected')}
                  className="px-6 py-3 rounded-lg bg-red-600 hover:bg-red-700 text-white font-medium transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
                >
                  Reject Report
                </button>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}

// Info Item Component for better consistency
function InfoItem({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col space-y-1">
      <span className="text-sm font-medium text-muted-foreground">{label}:</span>
      <span className="text-foreground font-medium">{value}</span>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    pending: 'bg-amber-500 shadow-amber-500/25',
    accepted: 'bg-emerald-500 shadow-emerald-500/25',
    rejected: 'bg-red-500 shadow-red-500/25',
    under_review: 'bg-amber-500 shadow-amber-500/25',
    investigating: 'bg-emerald-500 shadow-emerald-500/25',
  };

  const bgColor = colors[status] || 'bg-gray-500 shadow-gray-500/25';

  return (
    <span className={`px-4 py-2 rounded-full text-sm font-semibold text-white ${bgColor} shadow-lg`}>
      {status.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())}
    </span>
  );
}