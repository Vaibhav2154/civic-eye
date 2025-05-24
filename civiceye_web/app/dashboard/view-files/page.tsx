'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { supabase } from '@/lib/supabaseClient';
import { CrimeReport, ReportStatus } from '../../../types/index';
//is_anonymous is false always need to look into it
export default function Home() {
  const [reports, setReports] = useState<CrimeReport[]>([]);
  const [filteredReports, setFilteredReports] = useState<CrimeReport[]>([]);
  const [filter, setFilter] = useState<'all' | ReportStatus>('all');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchReports();
  }, []);

  
  useEffect(() => {
    if (filter === 'all') {
      setFilteredReports(reports);
    } else {
      setFilteredReports(reports.filter(report => report.status === filter));
    }
  }, [filter, reports]);

  async function fetchReports() {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('reports')
        .select('*')
        .order('submitted_at', { ascending: false });

      if (error) throw error;

      if (data) {
        setReports(data as CrimeReport[]);
        setFilteredReports(data as CrimeReport[]);
      }
    } catch (error) {
      console.error('Error fetching reports:', error);
    } finally {
      setLoading(false);
    }
  }

  async function updateReportStatus(id: string, status: ReportStatus) {
    try {
      const { error } = await supabase
        .from('reports')
        .update({ status })
        .eq('id', id);

      if (error) throw error;

      const updatedReport = reports.find(report => report.id === id);
      if (status === 'under_review' && updatedReport) {
        await sendAcceptanceEmail(updatedReport);
      }
      if(status === 'rejected' && updatedReport){
        await sendRejectedEmail(updatedReport)
      }
      setReports(prevReports =>
        prevReports.map(report =>
          report.id === id ? { ...report, status } : report
        )
      );
    } catch (error) {
      console.error('Error updating report status:', (error as Error).message);
    }
  }
  

  async function sendAcceptanceEmail(report: CrimeReport) {
    try {
      // Fetch user information using userId from the report
      const { data: userData, error: userError } = await supabase
        .from('users')
        .select('email, is_anonymous')
        .eq('id', report.userid)
        .single();

      if (userError) {
        console.error('Error fetching user data:', userError);
        return;
      }

      let recipients = [];
      let subject = '';
      let body = '';

      console.log(userData)
      if (userData.is_anonymous) {
        // Send to NGOs and lawyers
        recipients = ['bhumikapolis@gmail.com']; // Replace with actual NGO/lawyer emails
        subject = `New Crime Report Accepted - Professional Assistance Required: ${report.title}`;
        body = `
          A new anonymous crime report has been accepted and requires professional assistance.

          Report Details:
          Title: ${report.title}
          Category: ${report.category}
          Location: ${report.city}, ${report.state}, ${report.country}
          Description: ${report.description}
          Submitted: ${new Date(report.submitted_at).toLocaleDateString()}

          This is an anonymous report. Please coordinate among yourselves to provide appropriate legal and support services.

          Please take the necessary steps to assist with this case.
        `;
      } else {
        // Send to the user
        recipients = [userData.email];
        subject = `Your Crime Report Has Been Accepted: ${report.title}`;
        body = `
          Dear User,

          Your crime report has been reviewed and accepted. We want to help you get the assistance you need.

          Report Details:
          Title: ${report.title}
          Category: ${report.category}
          Location: ${report.city}, ${report.state}, ${report.country}
          Submitted: ${new Date(report.submitted_at).toLocaleDateString()}

          What help do you require?
          We can connect you with:
          - Legal assistance and counseling
          - Support services and resources
          - Guidance on next steps for your case

          Please reply to this email or contact us to let us know what specific help you need, and we will connect you with the appropriate professionals.

          We are here to support you through this process.

          Best regards,
          Crime Report Management Team
        `;
      }

      await fetch('/api/send-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          to: recipients,
          subject,
          text: body,
        }),
      });

    } catch (err) {
      console.error('Failed to send email:', err);
    }
  }

  async function sendRejectedEmail(report: CrimeReport) {
    try {
      // Fetch user information using userId from the report
      const { data: userData, error: userError } = await supabase
        .from('users')
        .select('email')
        .eq('id', report.userid)
        .single();

      if (userError) {
        console.error('Error fetching user data:', userError);
        return;
      }

      let recipients = [];
      let subject = '';
      let body = '';

      console.log(userData)
       
        // Send to the user
        recipients = [userData.email];
        subject = `Your Crime Report Has Been Rejected: ${report.title}`;
        body = `
          Dear User,

          Your crime report has been reviewed and accepted. We want to help you get the assistance you need.

          Report Details:
          Title: ${report.title}
          Category: ${report.category}
          Location: ${report.city}, ${report.state}, ${report.country}
          Submitted: ${new Date(report.submitted_at).toLocaleDateString()}

          Your report has been rejected . The following can be the reasons :
          -false case
          -rigged evidence

          Please reply to this email or contact us to let us know what specific help you need, and we will connect you with the appropriate professionals.

          We are here to support you through this process.

          Best regards,
          Crime Report Management Team
        `;
      

      await fetch('/api/send-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          to: recipients,
          subject,
          text: body,
        }),
      });

    } catch (err) {
      console.error('Failed to send email:', err);
    }
  }

  return (
    <div className="min-h-screen w-full flex flex-col" style={{ background: 'var(--background)', color: 'var(--foreground)' }}>
      <header className="w-full py-6 px-8 border-b sticky top-0 z-10" style={{ background: 'var(--background)', borderColor: 'var(--border)' }}>
        <h1 className="text-3xl font-bold" style={{ color: 'var(--secondary)' }}>Crime Report Management System</h1>
      </header>

      <main className="flex-grow w-full px-8 py-6">
        <div className="mb-8 overflow-x-auto sticky top-20 z-10 py-3" style={{ background: 'var(--background)' }}>
          <div className="flex gap-3 min-w-max">
            {['all', 'submitted', 'under_review', 'rejected'].map((type) => {
              const label = {
                all: 'All Reports',
                submitted: 'Pending',
                under_review: 'Accepted',
                rejected: 'Rejected'
              }[type];

              const bg = {
                all: 'var(--primary)',
                submitted: '#f59e0b',
                under_review: '#10b981',
                rejected: '#ef4444'
              }[type as ReportStatus | 'all'];

              const textColor = filter === type ? 'var(--background)' : 'var(--muted-foreground)';

              return (
                <button
                  key={type}
                  onClick={() => setFilter(type as any)}
                  className="px-6 py-2 rounded-full transition-colors duration-200"
                  style={{
                    background: filter === type ? bg : 'var(--card)',
                    color: textColor,
                    border: '1px solid var(--border)'
                  }}
                >
                  {label}
                </button>
              );
            })}
          </div>
        </div>

        {loading ? (
          <div className="flex justify-center items-center h-64">
            <div className="text-2xl" style={{ color: 'var(--secondary)' }}>Loading reports...</div>
          </div>
        ) : (
          <>
            {filteredReports.length === 0 ? (
              <div className="p-8 rounded-lg text-center" style={{ background: 'var(--card)', border: '1px solid var(--border)' }}>
                <p className="text-lg">No reports found.</p>
              </div>
            ) : (
              <div className="flex flex-col gap-6 pb-10">
                {filteredReports.map((report) => (
                  <div
                    key={report.id}
                    className="rounded-lg overflow-hidden transition-transform duration-200 hover:translate-y-[-4px] w-full"
                    style={{
                      background: 'var(--card)',
                      border: '1px solid var(--border)',
                      boxShadow: '0 4px 15px rgba(0, 0, 0, 0.15)'
                    }}
                  >
                    <div className="p-6 flex flex-col lg:flex-row">
                      <div className="flex-grow lg:w-3/4 lg:pr-6 mb-6 lg:mb-0">
                        <div className="flex flex-col sm:flex-row justify-between items-start mb-4 gap-3">
                          <h2 className="text-xl font-semibold" style={{ color: 'var(--secondary)' }}>{report.title}</h2>
                          <StatusBadge status={report.status} />
                        </div>

                        <div className="grid grid-cols-1 md:grid-cols-3 gap-y-3 gap-x-6 mb-6">
                          <p style={{ color: 'var(--muted-foreground)' }}>
                            <span className="font-medium" style={{ color: 'var(--foreground)' }}>Category:</span> {report.category}
                          </p>
                          <p style={{ color: 'var(--muted-foreground)' }}>
                            <span className="font-medium" style={{ color: 'var(--foreground)' }}>Date:</span> {new Date(report.submitted_at).toLocaleDateString()}
                          </p>
                          <p style={{ color: 'var(--muted-foreground)' }}>
                            <span className="font-medium" style={{ color: 'var(--foreground)' }}>Location:</span> {report.city}, {report.state}, {report.country}
                          </p>
                        </div>

                        <div className="mb-6 border-t pt-4" style={{ borderColor: 'var(--border)' }}>
                          <p className="line-clamp-3" style={{ color: 'var(--muted-foreground)' }}>{report.description}</p>
                        </div>
                      </div>

                      <div className="lg:w-1/4 lg:pl-6 lg:border-l flex flex-col justify-center" style={{ borderColor: 'var(--border)' }}>
                        <Link
                          href={`/dashboard/reports/${report.id}`}
                          className="block w-full py-3 px-4 text-center rounded-md mb-4 transition-colors duration-200"
                          style={{
                            background: 'var(--primary)',
                            color: 'var(--primary-foreground)',
                            border: '1px solid var(--primary)'
                          }}
                        >
                          View Details
                        </Link>

                        {report.status === 'submitted' && (
                          <div className="flex space-x-4">
                            <button
                              onClick={() => updateReportStatus(report.id, 'under_review')}
                              className="flex-1 py-2 rounded-md transition-colors duration-200"
                              style={{ background: '#10b981', color: 'white' }}
                            >
                              Accept
                            </button>
                            <button
                              onClick={() => updateReportStatus(report.id, 'rejected')}
                              className="flex-1 py-2 rounded-md transition-colors duration-200"
                              style={{ background: '#ef4444', color: 'white' }}
                            >
                              Reject
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </main>
    </div>
  );
}

function StatusBadge({ status }: { status: ReportStatus }) {
  let style = { background: '', color: '#fff' };

  switch (status) {
    case 'submitted': style.background = '#f59e0b'; break;
    case 'under_review': style.background = '#10b981'; break;
    case 'rejected': style.background = '#ef4444'; break;
  }

  return (
    <span className="inline-block px-3 py-1 rounded-full text-xs font-medium" style={style}>
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  );
}