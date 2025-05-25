"use client"

import { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient';
import Image from 'next/image';

type EvidenceItem = {
  id: string;
  file_url: string;
  file_type: string;
  uploaded_at: string;
  hash?: string;
  report_id?: string;
};

export default function EvidencePage() {
  const params = useParams();
  const router = useRouter();
  const reportId = params?.id as string;

  // Debug logging to verify params
  useEffect(() => {
    console.log('URL params:', params);
    console.log('Report ID:', reportId);
  }, [params, reportId]);
  
  const [evidence, setEvidence] = useState<EvidenceItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    console.log('Effect triggered, reportId:', reportId);
    if (reportId) {
      fetchEvidence();
    }
  }, [reportId]);

  const fetchEvidence = async () => {
    if (!reportId) {
      setError('No report ID found in URL');
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      console.log('Fetching evidence for report ID:', reportId);

      const { data, error: fetchError } = await supabase
        .from('evidence')
        .select('*')
        .eq('report_id', reportId)
        .order('uploaded_at', { ascending: false });

      if (fetchError) {
        console.error('Supabase error:', fetchError);
        throw fetchError;
      }

      console.log('Fetched evidence:', data);
      setEvidence(data || []);
    } catch (err) {
      console.error('Error fetching evidence:', err);
      setError(err instanceof Error ? err.message : 'An unknown error occurred');
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString: string): string => {
    if (!dateString) return 'Unknown date';
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getFileIcon = (fileType: string): string => {
    if (fileType?.startsWith('image/')) return '🖼️';
    if (fileType?.startsWith('video/')) return '🎥';
    if (fileType?.startsWith('audio/')) return '🎵';
    if (fileType?.includes('pdf')) return '📄';
    if (fileType?.includes('document') || fileType?.includes('word')) return '📝';
    if (fileType?.includes('spreadsheet') || fileType?.includes('excel')) return '📊';
    return '📎';
  };

  const isImage = (fileType: string | undefined): boolean => {
    return fileType?.startsWith('image/') ?? false;
  };

  const isVideo = (fileType: string | undefined): boolean => {
    return fileType?.startsWith('video/') ?? false;
  };

  const handleImageError = (e: React.SyntheticEvent<HTMLImageElement>) => {
    const img = e.target as HTMLImageElement;
    const fallback = img.parentElement?.querySelector('.fallback-display') as HTMLElement;
    if (fallback) {
      img.style.display = 'none';
      fallback.style.display = 'flex';
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-secondary mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading evidence...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="bg-card border border-border p-8 rounded-xl shadow-2xl max-w-md w-full mx-4 backdrop-blur-sm">
          <div className="text-center">
            <div className="text-destructive text-4xl mb-4">⚠️</div>
            <h2 className="text-xl font-semibold text-foreground mb-2">Error Loading Evidence</h2>
            <p className="text-muted-foreground mb-6">{error}</p>
            <button
              onClick={fetchEvidence}
              className="bg-primary hover:bg-primary/90 text-primary-foreground px-6 py-3 rounded-lg transition-all duration-200 font-medium shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
            >
              Try Again
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="container mx-auto px-6 py-8">
        <EvidenceHeader 
          reportId={reportId} 
          evidenceCount={evidence.length} 
          onBack={() => router.back()} 
        />
        
        {evidence.length === 0 ? (
          <EmptyState />
        ) : (
          <EvidenceGrid evidence={evidence} />
        )}
      </div>
    </div>
  );
}

// Header Component
function EvidenceHeader({ 
  reportId, 
  evidenceCount, 
  onBack 
}: { 
  reportId: string; 
  evidenceCount: number; 
  onBack: () => void; 
}) {
  return (
    <div className="mb-10">
      <button
        onClick={onBack}
        className="text-secondary hover:text-secondary/80 mb-6 flex items-center gap-2 transition-all duration-200 group font-medium"
      >
        <span className="transform group-hover:-translate-x-1 transition-transform duration-200">←</span> 
        Back to Report
      </button>
      <div className="space-y-3">
        <h1 className="text-4xl font-bold text-foreground bg-gradient-to-r from-foreground to-muted-foreground bg-clip-text">
          Evidence Collection
        </h1>
        <div className="flex items-center gap-4 text-muted-foreground">
          <span className="bg-accent/20 px-3 py-1 rounded-full text-sm font-medium">
            Report ID: {reportId}
          </span>
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 bg-secondary rounded-full animate-pulse"></div>
            <span className="text-sm">
              {evidenceCount} item{evidenceCount !== 1 ? 's' : ''} collected
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

// Empty State Component
function EmptyState() {
  return (
    <div className="bg-card border border-border rounded-xl shadow-xl p-16 text-center backdrop-blur-sm">
      <div className="text-muted-foreground/50 text-8xl mb-6">📁</div>
      <h3 className="text-2xl font-semibold text-foreground mb-3">No Evidence Found</h3>
      <p className="text-muted-foreground text-lg max-w-md mx-auto">
        There is no evidence associated with this report yet. Evidence will appear here once uploaded.
      </p>
      <div className="mt-8 flex justify-center">
        <div className="w-24 h-1 bg-gradient-to-r from-transparent via-accent to-transparent rounded-full"></div>
      </div>
    </div>
  );
}

// Evidence Grid Component
function EvidenceGrid({ evidence }: { evidence: EvidenceItem[] }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8">
      {evidence.map((item, index) => (
        <EvidenceCard 
          key={`${item.id}-${index}-${item.uploaded_at}`} 
          item={item} 
          index={index}
        />
      ))}
    </div>
  );
}

// Evidence Card Component
function EvidenceCard({ item, index }: { item: EvidenceItem; index: number }) {
  const formatDate = (dateString: string): string => {
    if (!dateString) return 'Unknown date';
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getFileIcon = (fileType: string): string => {
    if (fileType?.startsWith('image/')) return '🖼️';
    if (fileType?.startsWith('video/')) return '🎥';
    if (fileType?.startsWith('audio/')) return '🎵';
    if (fileType?.includes('pdf')) return '📄';
    if (fileType?.includes('document') || fileType?.includes('word')) return '📝';
    if (fileType?.includes('spreadsheet') || fileType?.includes('excel')) return '📊';
    return '📎';
  };

  const isImage = (fileType: string | undefined): boolean => {
    return fileType?.startsWith('image/') ?? false;
  };

  const isVideo = (fileType: string | undefined): boolean => {
    return fileType?.startsWith('video/') ?? false;
  };

  const handleImageError = (e: React.SyntheticEvent<HTMLImageElement>) => {
    const img = e.target as HTMLImageElement;
    const fallback = img.parentElement?.querySelector('.fallback-display') as HTMLElement;
    if (fallback) {
      img.style.display = 'none';
      fallback.style.display = 'flex';
    }
  };

  return (
    <div className="bg-card border border-border rounded-xl shadow-xl overflow-hidden hover:shadow-2xl transition-all duration-300 transform hover:-translate-y-2 backdrop-blur-sm group">
      <FilePreview 
        item={item} 
        isImage={isImage} 
        isVideo={isVideo} 
        getFileIcon={getFileIcon}
        onImageError={handleImageError}
      />
      <EvidenceInfo item={item} index={index} formatDate={formatDate} />
    </div>
  );
}

// File Preview Component
function FilePreview({ 
  item, 
  isImage, 
  isVideo, 
  getFileIcon,
  onImageError 
}: {
  item: EvidenceItem;
  isImage: (fileType: string | undefined) => boolean;
  isVideo: (fileType: string | undefined) => boolean;
  getFileIcon: (fileType: string) => string;
  onImageError: (e: React.SyntheticEvent<HTMLImageElement>) => void;
}) {
  return (
    <div className="aspect-video bg-muted/20 relative overflow-hidden">
      <div className="absolute inset-0 bg-gradient-to-br from-primary/5 to-secondary/5"></div>
      {isImage(item.file_type) ? (
        <div className="relative w-full h-full">
          <Image
            src={item.file_url}
            alt="Evidence"
            fill
            className="object-cover transition-transform duration-300 group-hover:scale-105"
            onError={onImageError}
          />
          <div className="fallback-display hidden absolute inset-0 bg-muted/20 items-center justify-center backdrop-blur-sm">
            <div className="text-center">
              <span className="text-muted-foreground text-sm">Image not available</span>
            </div>
          </div>
        </div>
      ) : isVideo(item.file_type) ? (
        <video
          src={item.file_url}
          className="w-full h-full object-cover"
          controls
          preload="metadata"
        />
      ) : (
        <div className="flex items-center justify-center h-full">
          <div className="text-center transform group-hover:scale-110 transition-transform duration-300">
            <div className="text-5xl mb-3 filter drop-shadow-lg">{getFileIcon(item.file_type)}</div>
            <p className="text-sm text-muted-foreground font-medium px-3 py-1 bg-background/50 rounded-full backdrop-blur-sm">
              {item.file_type || 'Unknown type'}
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

// Evidence Info Component
function EvidenceInfo({ 
  item, 
  index,
  formatDate 
}: { 
  item: EvidenceItem; 
  index: number;
  formatDate: (dateString: string) => string; 
}) {
  return (
    <div className="p-6">
      <div className="mb-4">
        <div className="flex items-center justify-between mb-2">
          <h3 className="font-bold text-foreground text-lg">
            Evidence #{index + 1}
          </h3>
          <div className="w-8 h-8 bg-secondary/20 rounded-full flex items-center justify-center">
            <span className="text-secondary text-xs font-bold">#{index + 1}</span>
          </div>
        </div>
        <p className="text-sm text-muted-foreground bg-accent/10 px-3 py-1 rounded-full inline-block">
          {formatDate(item.uploaded_at)}
        </p>
      </div>

      <div className="space-y-3 text-sm mb-6">
        <div className="flex justify-between items-center py-2 border-b border-border/50">
          <span className="text-muted-foreground font-medium">Type:</span>
          <span className="text-foreground font-mono text-xs bg-accent/20 px-2 py-1 rounded">
            {item.file_type || 'Unknown'}
          </span>
        </div>
        {item.hash && (
          <div className="flex justify-between items-center py-2">
            <span className="text-muted-foreground font-medium">Hash:</span>
            <span className="text-foreground font-mono text-xs bg-accent/20 px-2 py-1 rounded truncate ml-2">
              {item.hash.substring(0, 8)}...
            </span>
          </div>
        )}
      </div>

      <div className="flex gap-3">
        <a
          href={item.file_url}
          target="_blank"
          rel="noopener noreferrer"
          className="flex-1 bg-primary hover:bg-primary/90 text-primary-foreground text-center py-3 px-4 rounded-lg text-sm font-medium transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
        >
          View
        </a>
        <a
          href={item.file_url}
          download
          className="flex-1 bg-accent/20 hover:bg-accent/30 text-foreground text-center py-3 px-4 rounded-lg text-sm font-medium transition-all duration-200 border border-border hover:border-accent"
        >
          Download
        </a>
      </div>
    </div>
  );
}