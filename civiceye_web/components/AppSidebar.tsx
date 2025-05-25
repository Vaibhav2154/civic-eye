'use client'

import React, { useState, useEffect, useRef } from 'react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell, LineChart, Line, AreaChart, Area } from 'recharts';
import { Users, FileText, CheckCircle, Clock, XCircle, TrendingUp, Activity, AlertTriangle, BarChart3, Calendar, Home, Inbox, Search, Settings, Bot } from 'lucide-react';
import { supabase } from '../lib/supabaseClient';
import Image from 'next/image';

const menuItems = [
  {
    title: "Home",
    url: "/",
    icon: Home,
  },
  {
    title: "Postings",
    url: "/dashboard/view-files",
    icon: Inbox,
  },
  {
    title: "Analytics",
    url: "/dashboard",
    icon: BarChart3,
    active: true,
  },
   {
    title: "Chat Assistant",
    url: "/dashboard/chatbot",
    icon: Bot,
    active: true,
  },
  {
    title:"BlockChain Explorer",
    url:"/dashboard/blockchain",
    icon: BarChart3,
  },
  {
    title: "Settings",
    url: "/dashboard/settings",
    icon: Settings,
  },
];

// Sidebar Component
export default function AppSidebar(){
  return (
    <div className="flex h-full w-64 flex-col bg-slate-800/90 backdrop-blur-sm border-r border-slate-700/50">
      {/* Logo Section */}

      <div className="flex items-center gap-3 px-6 py-4 border-b border-slate-700/50">
        <div className="w-8 h-8  rounded-lg flex items-center justify-center">
          <Image src='/logo1.png' priority={true} alt='logo' height={100} width={100} />
        </div>
        <span className="text-xl font-bold text-slate-100">CivicEye</span>
      </div>
      
      {/* Navigation Menu */}
      <nav className="flex-1 px-4 py-6">
        <div className="space-y-2">
          <div className="px-3 py-2 text-xs font-semibold text-slate-400 uppercase tracking-wider">
            Navigation
          </div>
          <div className="space-y-1">
            {menuItems.map((item) => (
              <a
                key={item.title}
                href={item.url}
                className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                  item.active
                    ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30'
                    : 'text-slate-300 hover:text-slate-100 hover:bg-slate-700/50'
                }`}
              >
                <item.icon className="w-4 h-4" />
                {item.title}
              </a>
            ))}
          </div>
        </div>
      </nav>
    </div>
  );
};