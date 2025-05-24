'use client'

import React, { useState, useEffect } from 'react';
import { User as LucideUser, LogOut, Edit3, Save, X, Camera, Shield, CheckCircle, Clock, UserCheck } from 'lucide-react';
import { supabase } from '../../../lib/supabaseClient';
import type { User } from '@supabase/supabase-js';
import { useRouter } from 'next/navigation'

export default function SettingsPage() {
  const [isEditing, setIsEditing] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [profile, setProfile] = useState({
    id: '',
    full_name: '',
    email: '',
    phone: '',
    role: '',
    is_anonymous: false,
    created_at: '',
    last_active_at: '',
    is_verified_reporter: false,
    avatar_url: null
  });
  const [editForm, setEditForm] = useState({ ...profile });

  const route = useRouter();
  // Load user profile on component mount and auth state change
  useEffect(() => {
    // Get current user and set up auth listener
    const getCurrentUser = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        setCurrentUser(user);
        loadProfile(user.id);
      } else {
        setLoading(false);
      }
    };

    getCurrentUser();

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (session?.user) {
        setCurrentUser(session.user);
        loadProfile(session.user.id);
      } else {
        setCurrentUser(null);
        setLoading(false);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  const loadProfile = async (userid: string) => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('id', userid)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          // User doesn't exist in users table, create profile from auth user
          await createUserProfile(userid);
        } else {
          throw error;
        }
      } else if (data) {
        setProfile(data);
        setEditForm(data);
      }
    } catch (error) {
      console.error('Error loading profile:', error);
    } finally {
      setLoading(false);
    }
  };

  const createUserProfile = async (userId: string) => {
    try {
      const { data: authUser } = await supabase.auth.getUser();
      const newProfile = {
        id: userId,
        full_name: authUser.user?.user_metadata?.full_name || '',
        email: authUser.user?.email || '',
        phone: authUser.user?.phone || '',
        role: 'User',
        is_anonymous: false,
        is_verified_reporter: false,
        avatar_url: authUser.user?.user_metadata?.avatar_url || null,
        created_at: new Date().toISOString(),
        last_active_at: new Date().toISOString()
      };

      const { data, error } = await supabase
        .from('users')
        .insert([newProfile])
        .select()
        .single();

      if (error) throw error;

      setProfile(data);
      setEditForm(data);
    } catch (error) {
      console.error('Error creating user profile:', error);
    }
  };

  const handleEdit = () => {
    setIsEditing(true);
    setEditForm({ ...profile });
  };

  const handleSave = async () => {
    try {
      setSaving(true);
      
      const updateData = {
        full_name: editForm.full_name,
        email: editForm.email,
        phone: editForm.phone,
        is_anonymous: editForm.is_anonymous,
        last_active_at: new Date().toISOString()
      };

      const { data, error } = await supabase
        .from('users')
        .update(updateData)
        .eq('id', profile.id)
        .select()
        .single();

      if (error) throw error;

      setProfile(data);
      setIsEditing(false);
    } catch (error) {
      console.error('Error saving profile:', error);
      alert('Failed to save changes. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleCancel = () => {
    setEditForm({ ...profile });
    setIsEditing(false);
  };

  const handleLogout = async () => {
    if (window.confirm('Are you sure you want to logout?')) {
      try {
        const { error } = await supabase.auth.signOut();
        if (error) throw error;
        // Redirect will be handled by auth state change
      } catch (error) {
        console.error('Error logging out:', error);
        alert('Error logging out. Please try again.');
      }
      route.push('/')
    }
  };

  const handleInputChange = (field: string, value: any) => {
    setEditForm(prev => ({ ...prev, [field]: value }));
  };

  const formatDate = (dateString: string) => {
    if (!dateString) return 'Not available';
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  };

  const formatLastActive = (dateString: string) => {
    if (!dateString) return 'Never';
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffDays = Math.floor(diffHours / 24);

    if (diffHours < 1) return 'Just now';
    if (diffHours < 24) return `${diffHours} hours ago`;
    if (diffDays === 1) return 'Yesterday';
    return `${diffDays} days ago`;
  };

  if (!currentUser && !loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center p-4">
        <div className="bg-card border border-border rounded-2xl shadow-xl p-8 max-w-md w-full">
            <LucideUser className="w-16 h-16 text-muted-foreground mx-auto mb-4" />
            <h2 className="text-2xl font-bold text-foreground mb-2">Not Authenticated</h2>
            <p className="text-muted-foreground">Please log in to view your settings.</p>
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-background p-4">
        <div className="max-w-2xl mx-auto">
          <div className="bg-card border border-border rounded-2xl shadow-xl p-8">
            <div className="animate-pulse">
              <div className="h-8 bg-muted rounded w-1/4 mb-4"></div>
              <div className="h-4 bg-muted rounded w-1/2 mb-8"></div>
              <div className="h-32 bg-muted rounded-full w-32 mx-auto mb-6"></div>
              <div className="space-y-4">
                <div className="h-4 bg-muted rounded w-3/4"></div>
                <div className="h-4 bg-muted rounded w-1/2"></div>
                <div className="h-4 bg-muted rounded w-2/3"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background p-4">
      <div className="max-w-2xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-foreground mb-2">Settings</h1>
          <p className="text-muted-foreground">Manage your account settings and preferences</p>
        </div>

        {/* Profile Section */}
        <div className="bg-card border border-border rounded-2xl shadow-xl overflow-hidden mb-6">
          <div className="bg-gradient-to-r from-primary to-secondary h-32 relative">
            <div className="absolute -bottom-16 left-8">
              <div className="w-32 h-32 bg-card rounded-full border-4 border-card shadow-lg flex items-center justify-center relative group cursor-pointer">
                {profile.avatar_url ? (
                  <img 
                    src={profile.avatar_url} 
                    alt="Profile" 
                    className="w-full h-full rounded-full object-cover"
                  />
                ) : (
                  <LucideUser className="w-12 h-12 text-muted-foreground" />
                )}
                <div className="absolute inset-0 bg-black bg-opacity-50 rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                  <Camera className="w-6 h-6 text-white" />
                </div>
              </div>
            </div>
          </div>

          <div className="pt-20 pb-8 px-8">
            <div className="flex justify-between items-start mb-6">
              <div>
                <div className="flex items-center gap-3 mb-2">
                  <h2 className="text-2xl font-bold text-card-foreground">
                    {profile.full_name || 'Your Name'}
                  </h2>
                  {profile.is_verified_reporter && (
                    <div className="flex items-center gap-1 bg-green-500/20 text-green-400 px-2 py-1 rounded-full text-xs font-medium border border-green-500/30">
                      <CheckCircle className="w-3 h-3" />
                      Verified
                    </div>
                  )}
                  {profile.is_anonymous && (
                    <div className="flex items-center gap-1 bg-amber-500/20 text-amber-400 px-2 py-1 rounded-full text-xs font-medium border border-amber-500/30">
                      <Shield className="w-3 h-3" />
                      Anonymous
                    </div>
                  )}
                </div>
                <p className="text-muted-foreground">{profile.email || 'your.email@example.com'}</p>
                <div className="flex items-center gap-4 mt-2 text-sm text-muted-foreground">
                  <span className="flex items-center gap-1">
                    <UserCheck className="w-4 h-4" />
                    {profile.role || 'User'}
                  </span>
                  <span className="flex items-center gap-1">
                    <Clock className="w-4 h-4" />
                    Active {formatLastActive(profile.last_active_at)}
                  </span>
                </div>
              </div>
              {!isEditing && (
                <button
                  onClick={handleEdit}
                  className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
                >
                  <Edit3 className="w-4 h-4" />
                  Edit Profile
                </button>
              )}
            </div>

            {isEditing ? (
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-card-foreground mb-2">Full Name</label>
                  <input
                    type="text"
                    value={editForm.full_name}
                    onChange={(e) => handleInputChange('full_name', e.target.value)}
                    placeholder="Enter your full name"
                    className="w-full px-4 py-3 bg-input border border-border rounded-lg focus:ring-2 focus:ring-ring focus:border-transparent outline-none transition-all text-foreground placeholder:text-muted-foreground"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-card-foreground mb-2">Email</label>
                  <input
                    type="email"
                    value={editForm.email}
                    onChange={(e) => handleInputChange('email', e.target.value)}
                    placeholder="your.email@example.com"
                    className="w-full px-4 py-3 bg-input border border-border rounded-lg focus:ring-2 focus:ring-ring focus:border-transparent outline-none transition-all text-foreground placeholder:text-muted-foreground"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-card-foreground mb-2">Phone</label>
                  <input
                    type="tel"
                    value={editForm.phone}
                    onChange={(e) => handleInputChange('phone', e.target.value)}
                    placeholder="+1 (555) 123-4567"
                    className="w-full px-4 py-3 bg-input border border-border rounded-lg focus:ring-2 focus:ring-ring focus:border-transparent outline-none transition-all text-foreground placeholder:text-muted-foreground"
                  />
                </div>
                <div>
                  <label className="flex items-center gap-3 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={editForm.is_anonymous}
                      onChange={(e) => handleInputChange('is_anonymous', e.target.checked)}
                      className="w-4 h-4 text-primary border-border rounded focus:ring-primary bg-input"
                    />
                    <span className="text-sm font-medium text-card-foreground">
                      Keep my profile anonymous
                    </span>
                  </label>
                  <p className="text-xs text-muted-foreground mt-1 ml-7">
                    When enabled, your name won't be displayed publicly
                  </p>
                </div>
                <div className="flex gap-3 pt-4">
                  <button
                    onClick={handleSave}
                    disabled={saving}
                    className="flex items-center gap-2 px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <Save className="w-4 h-4" />
                    {saving ? 'Saving...' : 'Save Changes'}
                  </button>
                  <button
                    onClick={handleCancel}
                    disabled={saving}
                    className="flex items-center gap-2 px-6 py-3 bg-muted text-muted-foreground rounded-lg hover:bg-muted/80 transition-colors font-medium disabled:opacity-50"
                  >
                    <X className="w-4 h-4" />
                    Cancel
                  </button>
                </div>
              </div>
            ) : (
              <div className="space-y-4">
                <div>
                  <h3 className="text-sm font-medium text-card-foreground mb-1">Phone</h3>
                  <p className="text-muted-foreground">{profile.phone || 'No phone number provided'}</p>
                </div>
                <div>
                  <h3 className="text-sm font-medium text-card-foreground mb-1">Member Since</h3>
                  <p className="text-muted-foreground">{formatDate(profile.created_at)}</p>
                </div>
                <div>
                  <h3 className="text-sm font-medium text-card-foreground mb-1">Account Status</h3>
                  <div className="flex items-center gap-2">
                    <span className="text-muted-foreground">
                      {profile.is_verified_reporter ? 'Verified Reporter' : 'Standard User'}
                    </span>
                    {profile.is_verified_reporter && (
                      <CheckCircle className="w-4 h-4 text-green-400" />
                    )}
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Quick Actions */}
        <div className="bg-card border border-border rounded-2xl shadow-xl p-6">
          <h3 className="text-xl font-bold text-card-foreground mb-4">Quick Actions</h3>
          <div className="space-y-3">
            <button className="w-full flex items-center gap-3 p-4 text-left hover:bg-accent/10 rounded-xl transition-colors">
              <div className="w-10 h-10 bg-primary/20 rounded-full flex items-center justify-center">
                <Shield className="w-5 h-5 text-primary" />
              </div>
              <div>
                <h4 className="font-medium text-card-foreground">Privacy Settings</h4>
                <p className="text-sm text-muted-foreground">Manage your privacy and data preferences</p>
              </div>
            </button>

            <button className="w-full flex items-center gap-3 p-4 text-left hover:bg-accent/10 rounded-xl transition-colors">
              <div className="w-10 h-10 bg-green-500/20 rounded-full flex items-center justify-center">
                <CheckCircle className="w-5 h-5 text-green-400" />
              </div>
              <div>
                <h4 className="font-medium text-card-foreground">Verification Status</h4>
                <p className="text-sm text-muted-foreground">
                  {profile.is_verified_reporter 
                    ? 'Your reporter status is verified' 
                    : 'Apply for reporter verification'
                  }
                </p>
              </div>
            </button>
            
            <button 
              onClick={handleLogout}
              className="w-full flex items-center gap-3 p-4 text-left hover:bg-red-500/10 rounded-xl transition-colors group"
            >
              <div className="w-10 h-10 bg-red-500/20 rounded-full flex items-center justify-center group-hover:bg-red-500/30 transition-colors">
                <LogOut className="w-5 h-5 text-red-400" />
              </div>
              <div>
                <h4 className="font-medium text-red-400">Logout</h4>
                <p className="text-sm text-red-400/70">Sign out of your account</p>
              </div>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}