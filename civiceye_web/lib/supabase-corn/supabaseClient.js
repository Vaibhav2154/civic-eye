import { createClient } from '@supabase/supabase-js'

const NEXT_PUBLIC_SUPABASE_URL = "https://hghqehukyadoghlnjndz.supabase.co"
const NEXT_PUBLIC_SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhnaHFlaHVreWFkb2dobG5qbmR6Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQ4MDE0NywiZXhwIjoyMDYzMDU2MTQ3fQ.RgGj5wdao8y1iqrRE3dmMk_bdbijOGF9-wrIVldC-xY"
const supabaseUrl = NEXT_PUBLIC_SUPABASE_URL
const supabaseServiceKey = NEXT_PUBLIC_SUPABASE_SERVICE_KEY

export const supabase = createClient(supabaseUrl, supabaseServiceKey)
