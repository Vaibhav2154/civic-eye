export type ReportStatus = 'under_review' | 'rejected' | 'submitted';

export interface CrimeReport {
  id: string;
  userid: string;
  title: string;
  description: string;
  category: string;
  city: string;
  state: string;
  country: string;
  latitude: number;
  longitude: number;
  is_anonymous: boolean;
  reporter_id: string;
  status: ReportStatus;
  submitted_at: string;
}

export type FileType = 'image' | 'audio' | 'video' | 'unknown';

export interface ValidationResult {
  file: string;
  tampered: boolean;
  error?: string;
}

export interface ValidationResults {
  [key: string]: ValidationResult;
}
