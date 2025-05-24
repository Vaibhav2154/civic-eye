'use client';

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabaseClient';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useRouter } from 'next/navigation';
import { Loader2 } from 'lucide-react';

export default function EditProfile() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [user, setUser] = useState<any>(null);

  const [fullName, setFullName] = useState('');
  const [bio, setBio] = useState('');
  const [avatarUrl, setAvatarUrl] = useState('');

  useEffect(() => {
    const fetchProfile = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (user) {
        setUser(user);
        setFullName(user.user_metadata?.full_name || '');
        setAvatarUrl(user.user_metadata?.avatar_url || '');
        setBio(user.user_metadata?.bio || '');
      }
    };

    fetchProfile();
  }, []);

  const handleUpdate = async () => {
  setLoading(true);

  const { error: authError } = await supabase.auth.updateUser({
    data: {
      full_name: fullName,
      avatar_url: avatarUrl,
    },
  });

 
  const { error: dbError } = await supabase
    .from('users') 
    .update({
      full_name: fullName,
      avatar_url: avatarUrl,
      
    })
    .eq('id', user?.id); 

  setLoading(false);

  if (!authError && !dbError) {
    router.push('/');
  } else {
    alert(`Error updating profile: ${authError?.message || dbError?.message}`);
  }
};


  if (!user) {
    return <div className="min-h-screen flex items-center justify-center text-muted">Loading...</div>;
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4 py-12">
      <div className="w-full max-w-md bg-card p-8 rounded-2xl shadow-md border border-white/10 backdrop-blur-sm">
        <h2 className="text-2xl font-bold text-center mb-6 text-foreground">Edit Profile</h2>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-foreground mb-1">Full Name</label>
            <Input value={fullName} onChange={(e) => setFullName(e.target.value)} />
          </div>

          <div>
            <label className="block text-sm font-medium text-foreground mb-1">Avatar URL</label>
            <Input value={avatarUrl} onChange={(e) => setAvatarUrl(e.target.value)} />
          </div>

          <Button
            onClick={handleUpdate}
            className="w-full bg-gradient-to-r from-secondary to-primary text-foreground"
            disabled={loading}
          >
            {loading ? (
              <span className="flex items-center justify-center gap-2">
                <Loader2 className="w-4 h-4 animate-spin" /> Saving...
              </span>
            ) : (
              'Save Changes'
            )}
          </Button>
        </div>
      </div>
    </div>
  );
}
