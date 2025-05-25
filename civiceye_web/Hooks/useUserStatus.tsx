// hooks/useUser.ts
import { useEffect, useState } from 'react';
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';
import { User } from '@supabase/supabase-js';

export function useUserStatus() {
  const supabase = createClientComponentClient();
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchUser = async () => {
      const { data } = await supabase.auth.getUser();
      setUser(data.user ?? null);
      setLoading(false);
    };

    fetchUser();
  }, []);

  const avatarUrl = user?.user_metadata?.avatar_url || '/default-avatar.png';

  return { user, loading, isLoggedIn: !!user, avatarUrl };
}
