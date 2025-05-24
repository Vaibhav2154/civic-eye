'use client'

import React, { useState, useEffect, useRef } from 'react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell, LineChart, Line, AreaChart, Area } from 'recharts';
import { Users, FileText, CheckCircle, Clock, XCircle, TrendingUp, Activity, AlertTriangle, BarChart3, Calendar, Home, Inbox, Search, Settings, Bot } from 'lucide-react';
import { supabase } from '../lib/supabaseClient';
import Image from 'next/image';
import AppSidebar from './AppSidebar';

interface AnalyticsData {
  totalUsers: number;
  totalReports: number;
  submittedReports: number;
  underReviewReports: number;
  rejectedReports: number;
  loading: boolean;
}

interface AnimatedValues {
  totalUsers: number;
  totalReports: number;
  submittedReports: number;
  underReviewReports: number;
  rejectedReports: number;
}

interface ChartData {
  name: string;
  value: number;
  color: string;
}

interface TrendDataPoint {
  month: string;
  reports: number;
  users: number;
}

interface StatCardProps {
  title: string;
  value: number;
  icon: React.ComponentType<{ size?: number; className?: string; style?: React.CSSProperties }>;
  color: string;
  gradient: string;
  trend?: number;
}

// Menu items for sidebar
<AppSidebar/>

// Main Dashboard Component
export default function IntegratedDashboard() {
  const [data, setData] = useState<AnalyticsData>({
    totalUsers: 0,
    totalReports: 0,
    submittedReports: 0,
    underReviewReports: 0,
    rejectedReports: 0,
    loading: true
  });

  const [animatedValues, setAnimatedValues] = useState<AnimatedValues>({
    totalUsers: 0,
    totalReports: 0,
    submittedReports: 0,
    underReviewReports: 0,
    rejectedReports: 0
  });

  const [error, setError] = useState<string | null>(null);
  const timersRef = useRef<ReturnType<typeof setInterval>[]>([]);

  // Enhanced Supabase data fetching function
  const getStats = async () => {
    try {
      setError(null);
      
      // 1. Count total number of users
      const { count: totalUsers, error: usersError } = await supabase
        .from('users')
        .select('*', { count: 'exact', head: true });

      // 2. Count total number of reports
      const { count: totalReports, error: reportsError } = await supabase
        .from('reports')
        .select('*', { count: 'exact', head: true });

      // 3. Count reports under review
      const { count: underReviewReports, error: underReviewError } = await supabase
        .from('reports')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'under_review');

      // 4. Count reports rejected
      const { count: rejectedReports, error: rejectedError } = await supabase
        .from('reports')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'rejected');

      // 5. Count submitted reports (assuming 'submitted' status)
      const { count: submittedReports, error: submittedError } = await supabase
        .from('reports')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'submitted');

      // Handle errors
      if (usersError || reportsError || underReviewError || rejectedError || submittedError) {
        const errorMessage = 
          usersError?.message ||
          reportsError?.message ||
          underReviewError?.message ||
          rejectedError?.message ||
          submittedError?.message ||
          'Unknown error occurred';
        
        throw new Error(errorMessage);
      }

      // Return stats with fallback values
      return {
        totalUsers: totalUsers || 0,
        totalReports: totalReports || 0,
        underReviewReports: underReviewReports || 0,
        rejectedReports: rejectedReports || 0,
        submittedReports: submittedReports || 0,
      };
    } catch (err) {
      console.error('Error fetching stats:', err);
      throw err;
    }
  };

  // Fetch analytics data from Supabase
  const fetchAnalyticsData = async (): Promise<void> => {
    try {
      setData(prev => ({ ...prev, loading: true }));
      
      const stats = await getStats();
      
      if (stats) {
        setData({
          totalUsers: stats.totalUsers,
          totalReports: stats.totalReports,
          submittedReports: stats.submittedReports,
          underReviewReports: stats.underReviewReports,
          rejectedReports: stats.rejectedReports,
          loading: false
        });
      } else {
        throw new Error('Failed to fetch stats');
      }

    } catch (error) {
      console.error('Error fetching analytics:', error);
      setError(error instanceof Error ? error.message : 'Failed to fetch analytics data');
      
      // Set fallback data on error
      setData({
        totalUsers: 0,
        totalReports: 0,
        submittedReports: 0,
        underReviewReports: 0,
        rejectedReports: 0,
        loading: false
      });
    }
  };

  // Initial data fetch
  useEffect(() => {
    fetchAnalyticsData();
    
    // Set up periodic refresh (every 30 seconds)
    const interval = setInterval(fetchAnalyticsData, 30000);
    
    // Cleanup function
    return () => {
      clearInterval(interval);
      timersRef.current.forEach(timer => clearInterval(timer));
    };
  }, []);

  // Animate counters when data changes
  useEffect(() => {
    if (!data.loading) {
      // Clear existing timers
      timersRef.current.forEach(timer => clearInterval(timer));
      timersRef.current = [];

      const duration = 2000;
      const steps = 60;
      const stepDuration = duration / steps;

      (Object.keys(data) as Array<keyof AnalyticsData>).forEach(key => {
        if (key !== 'loading') {
          let currentStep = 0;
          const targetValue = data[key] as number;
          const increment = targetValue / steps;

          const timer = setInterval(() => {
            currentStep++;
            const currentValue = Math.min(Math.floor(increment * currentStep), targetValue);
            
            setAnimatedValues(prev => ({
              ...prev,
              [key]: currentValue
            }));

            if (currentStep >= steps) {
              clearInterval(timer);
            }
          }, stepDuration);

          timersRef.current.push(timer);
        }
      });
    }
  }, [data]);

  const pieChartData: ChartData[] = [
    { name: 'Under Review', value: animatedValues.underReviewReports, color: '#80b0ff' },
    { name: 'Submitted', value: animatedValues.submittedReports, color: '#1e3b8a' },
    { name: 'Rejected', value: animatedValues.rejectedReports, color: '#b1bdc4' }
  ];

  const barChartData: ChartData[] = [
    { name: 'Total Users', value: animatedValues.totalUsers, color: '#1e3b8a' },
    { name: 'Total Reports', value: animatedValues.totalReports, color: '#80b0ff' },
    { name: 'Under Review', value: animatedValues.underReviewReports, color: '#80b0ff' },
    { name: 'Submitted', value: animatedValues.submittedReports, color: '#1e3b8a' },
    { name: 'Rejected', value: animatedValues.rejectedReports, color: '#b1bdc4' }
  ];

  // Calculate processing rate
  const processingRate = data.totalReports > 0 
    ? Math.round(((data.totalReports - data.submittedReports) / data.totalReports) * 100)
    : 0;

  // Generate trend data based on current data (you can enhance this with actual historical data)
  const trendData: TrendDataPoint[] = [
    { month: 'Jan', reports: Math.floor(data.totalReports * 0.1), users: Math.floor(data.totalUsers * 0.1) },
    { month: 'Feb', reports: Math.floor(data.totalReports * 0.2), users: Math.floor(data.totalUsers * 0.2) },
    { month: 'Mar', reports: Math.floor(data.totalReports * 0.4), users: Math.floor(data.totalUsers * 0.4) },
    { month: 'Apr', reports: Math.floor(data.totalReports * 0.6), users: Math.floor(data.totalUsers * 0.6) },
    { month: 'May', reports: Math.floor(data.totalReports * 0.8), users: Math.floor(data.totalUsers * 0.8) },
    { month: 'Jun', reports: data.totalReports, users: data.totalUsers }
  ];

  const StatCard: React.FC<StatCardProps> = ({ title, value, icon: Icon, color, gradient, trend }) => (
    <div className="relative overflow-hidden rounded-2xl p-6 bg-slate-800/50 border border-slate-700/50 transition-all duration-300 hover:scale-105 hover:shadow-2xl group backdrop-blur-sm">
      <div className="absolute inset-0 bg-gradient-to-br from-white/5 to-transparent"></div>
      <div className="relative z-10">
        <div className="flex items-center justify-between mb-4">
          <div className="p-3 rounded-xl bg-white/10 backdrop-blur-sm">
            <Icon size={24} style={{ color }} />
          </div>
          {trend !== undefined && (
            <div className={`flex items-center text-sm ${trend >= 0 ? 'text-green-400' : 'text-red-400'}`}>
              <TrendingUp size={16} className="mr-1" />
              {trend >= 0 ? '+' : ''}{trend}%
            </div>
          )}
        </div>
        <div className="text-3xl font-bold mb-2 text-slate-100">
          {data.loading ? (
            <div className="animate-pulse bg-white/20 h-8 w-16 rounded"></div>
          ) : (
            value.toLocaleString()
          )}
        </div>
        <div className="text-sm font-medium text-slate-400">{title}</div>
      </div>
      <div className="absolute -right-4 -bottom-4 w-24 h-24 rounded-full bg-white/5 group-hover:scale-110 transition-transform duration-300"></div>
    </div>
  );

  if (data.loading) {
    return (
      <div className="flex h-screen bg-slate-900">
        <AppSidebar />
        <div className="flex-1 flex items-center justify-center">
          <div className="text-center">
            <div className="animate-spin rounded-full h-16 w-16 border-4 border-blue-500 border-t-transparent mx-auto mb-4"></div>
            <p className="text-xl text-slate-100">Loading Analytics...</p>
            <p className="text-sm text-slate-400 mt-2">Fetching data from Supabase...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex h-screen bg-slate-900">
      {/* Sidebar */}
      <AppSidebar />
      
      {/* Main Content */}
      <div className="flex-1 overflow-auto">
        <div className="h-full p-6">
          <div className="max-w-full mx-auto h-full">
            {/* Header */}
            <div className="mb-6">
              <div className="flex items-center justify-between">
                <div>
                  <h1 className="text-3xl font-bold mb-2 text-blue-400">
                    Analytics Dashboard
                  </h1>
                  <p className="text-slate-400">Real-time insights from your Supabase database</p>
                </div>
                <div className="flex items-center space-x-4">
                  <button 
                    onClick={fetchAnalyticsData}
                    className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors flex items-center space-x-2"
                    disabled={data.loading}
                  >
                    <Activity size={16} />
                    <span>Refresh</span>
                  </button>
                  {error && (
                    <div className="text-red-400 text-sm">
                      Error: {error}
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Stats Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-5 gap-4 mb-6">
              <StatCard 
                title="Total Users" 
                value={animatedValues.totalUsers} 
                icon={Users} 
                color="#3b82f6"
                gradient="linear-gradient(135deg, #3b82f6, #1e40af)"
                trend={12}
              />
              <StatCard 
                title="Total Reports" 
                value={animatedValues.totalReports} 
                icon={FileText} 
                color="#80b0ff"
                gradient="linear-gradient(135deg, #80b0ff, #3b82f6)"
                trend={8}
              />
              <StatCard 
                title="Under Review" 
                value={animatedValues.underReviewReports} 
                icon={Clock} 
                color="#80b0ff"
                gradient="linear-gradient(135deg, #80b0ff, #3b82f6)"
                trend={15}
              />
              <StatCard 
                title="Submitted" 
                value={animatedValues.submittedReports} 
                icon={CheckCircle} 
                color="#22c55e"
                gradient="linear-gradient(135deg, #22c55e, #16a34a)"
                trend={-3}
              />
              <StatCard 
                title="Rejected" 
                value={animatedValues.rejectedReports} 
                icon={XCircle} 
                color="#ef4444"
                gradient="linear-gradient(135deg, #ef4444, #dc2626)"
                trend={-8}
              />
            </div>

            {/* Charts Grid */}
            <div className="grid grid-cols-1 xl:grid-cols-2 gap-6 mb-6">
              {/* Pie Chart */}
              <div className="bg-slate-800/50 backdrop-blur-sm rounded-2xl p-5 border border-slate-700/50">
                <h3 className="text-lg font-semibold mb-4 flex items-center text-slate-100">
                  <Activity className="mr-2" size={18} />
                  Report Status Distribution
                </h3>
                <ResponsiveContainer width="100%" height={280}>
                  <PieChart>
                    <Pie
                      data={pieChartData}
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      dataKey="value"
                      animationBegin={0}
                      animationDuration={1500}
                    >
                      {pieChartData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip 
                      contentStyle={{
                        backgroundColor: '#1e293b',
                        border: 'none',
                        borderRadius: '8px',
                        color: '#f1f5f9'
                      }}
                    />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              </div>

              {/* Bar Chart */}
              <div className="bg-slate-800/50 backdrop-blur-sm rounded-2xl p-5 border border-slate-700/50">
                <h3 className="text-lg font-semibold mb-4 flex items-center text-slate-100">
                  <BarChart3 className="mr-2" size={18} />
                  System Overview
                </h3>
                <ResponsiveContainer width="100%" height={280}>
                  <BarChart data={barChartData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                    <XAxis 
                      dataKey="name" 
                      tick={{ fill: '#94a3b8', fontSize: 12 }}
                      angle={-45}
                      textAnchor="end"
                      height={80}
                    />
                    <YAxis tick={{ fill: '#94a3b8' }} />
                    <Tooltip 
                      contentStyle={{
                        backgroundColor: '#1e293b',
                        border: 'none',
                        borderRadius: '8px',
                        color: '#f1f5f9'
                      }}
                    />
                    <Bar 
                      dataKey="value" 
                      radius={[4, 4, 0, 0]}
                      animationDuration={1500}
                    >
                      {barChartData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>

            {/* Trend Chart */}
            <div className="bg-slate-800/50 backdrop-blur-sm rounded-2xl p-5 border border-slate-700/50 mb-6">
              <h3 className="text-lg font-semibold mb-4 flex items-center text-slate-100">
                <TrendingUp className="mr-2" size={18} />
                Monthly Growth Trends
              </h3>
              <ResponsiveContainer width="100%" height={320}>
                <AreaChart data={trendData}>
                  <defs>
                    <linearGradient id="colorReports" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#80b0ff" stopOpacity={0.8}/>
                      <stop offset="95%" stopColor="#80b0ff" stopOpacity={0.1}/>
                    </linearGradient>
                    <linearGradient id="colorUsers" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#1e3b8a" stopOpacity={0.8}/>
                      <stop offset="95%" stopColor="#1e3b8a" stopOpacity={0.1}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                  <XAxis dataKey="month" tick={{ fill: '#94a3b8' }} />
                  <YAxis tick={{ fill: '#94a3b8' }} />
                  <Tooltip 
                    contentStyle={{
                      backgroundColor: '#1e293b',
                      border: 'none',
                      borderRadius: '8px',
                      color: '#f1f5f9'
                    }}
                  />
                  <Area
                    type="monotone"
                    dataKey="reports"
                    stroke="#80b0ff"
                    fillOpacity={1}
                    fill="url(#colorReports)"
                    strokeWidth={3}
                    animationDuration={2000}
                  />
                  <Area
                    type="monotone"
                    dataKey="users"
                    stroke="#1e3b8a"
                    fillOpacity={1}
                    fill="url(#colorUsers)"
                    strokeWidth={3}
                    animationDuration={2000}
                  />
                  <Legend />
                </AreaChart>
              </ResponsiveContainer>
            </div>

            {/* Alert Section */}
            <div className="bg-slate-800/50 backdrop-blur-sm rounded-2xl p-5 border border-slate-700/50">
              <div className="flex items-center mb-4">
                <AlertTriangle className="mr-3 text-amber-400" size={20} />
                <h3 className="text-lg font-semibold text-slate-100">System Status</h3>
              </div>
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                <div className="bg-white/5 rounded-lg p-4">
                  <p className="font-medium text-amber-400">Pending Reports</p>
                  <p className="text-2xl font-bold text-slate-100">{animatedValues.submittedReports}</p>
                  <p className="text-sm text-slate-400">Require immediate attention</p>
                </div>
                <div className="bg-white/5 rounded-lg p-4">
                  <p className="font-medium text-blue-400">Processing Rate</p>
                  <p className="text-2xl font-bold text-slate-100">{processingRate}%</p>
                  <p className="text-sm text-slate-400">Reports processed</p>
                </div>
                <div className="bg-white/5 rounded-lg p-4">
                  <p className="font-medium text-green-400">Database Status</p>
                  <p className="text-2xl font-bold text-slate-100">{error ? 'Error' : 'Online'}</p>
                  <p className="text-sm text-slate-400">Supabase connection</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}