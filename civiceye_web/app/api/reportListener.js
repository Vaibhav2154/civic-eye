// report-listener.js
import { supabase } from '../../lib/supabase-corn/supabaseClient.js'; // use .js even if it's written in TS or compiled
import { sendReportEmail } from './mailer.js';



console.log('📡 Listening for new reports...');

const channel = supabase
  .channel('report-insert-channel')
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'reports',
    },
    async (payload) => {
      console.log('🚨 New report detected:', payload.new);
      try {
        await sendReportEmail(payload.new);
        console.log(`📧 Email sent for report ID: ${payload.new.id}`);
      } catch (err) {
        console.error('❌ Failed to send email:', err);
      }
    }
  )
  .subscribe();
