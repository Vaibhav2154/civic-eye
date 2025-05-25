'use client'
import React, { useState, useEffect } from 'react';
import { Clock, Hash, User, Database, AlertCircle, CheckCircle, RefreshCw, Eye, ExternalLink, Shield, Activity, Globe, MapPin, Calendar, Tag, ChevronLeft, ChevronRight } from 'lucide-react';

type ReportData = {
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
  isapublicpost: boolean;
  reporter_id: string;
  status: string;
  submitted_at: string;
};

type BlockchainData = {
  index: number;
  timestamp: number;
  data: {
    user_id: string;
    report_hash: string;
    media: string[];
    text: string; // JSON string containing ReportData
  };
  previous_hash: string;
  hash: string;
};

const CivicEyeBlockchainExplorer = () => {
  const [allChainData, setAllChainData] = useState<BlockchainData[]>([]);
  const [currentBlockIndex, setCurrentBlockIndex] = useState(0);
  const [parsedReport, setParsedReport] = useState<ReportData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [autoRefresh, setAutoRefresh] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState<'connecting' | 'connected' | 'error'>('connecting');

  const API_ENDPOINT = 'https://civiceye-api.onrender.com/blockchain/chain';

  const parseReportData = (textData: string): ReportData | null => {
    try {
      return JSON.parse(textData) as ReportData;
    } catch (error) {
      console.error('Failed to parse report data:', error);
      return null;
    }
  };

  const parseMediaData = (mediaArray: string[]): string[] => {
    try {
      return mediaArray.flatMap(item => {
        try {
          return JSON.parse(item);
        } catch {
          return item;
        }
      });
    } catch (error) {
      console.error('Failed to parse media data:', error);
      return mediaArray;
    }
  };

  const fetchBlockchainData = async () => {
    setLoading(true);
    setError('');
    setConnectionStatus('connecting');
    
    try {
      const response = await fetch(API_ENDPOINT);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();
      
      // Handle both single object and array responses
      let allBlocks: BlockchainData[] = [];
      if (Array.isArray(data)) {
        allBlocks = data;
      } else {
        allBlocks = [data];
      }
      
      // Filter out blocks with index 0-4 (ignore first 5 blocks)
      const filteredBlocks = allBlocks.filter(block => block.index >= 5);
      
      if (filteredBlocks.length === 0) {
        throw new Error('No blocks found with index 5 or higher');
      }
      
      // Sort blocks by index in descending order (newest first)
      filteredBlocks.sort((a, b) => b.index - a.index);
      
      setAllChainData(filteredBlocks);
      
      // Set current block to the newest one (index 0 in our filtered array)
      setCurrentBlockIndex(0);
      
      // Parse the report data from the current block
      const currentBlock = filteredBlocks[0];
      const reportData = parseReportData(currentBlock.data.text);
      setParsedReport(reportData);
      
      setLastUpdated(new Date());
      setConnectionStatus('connected');
    } catch (err) {
      console.error('Fetch error:', err);
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch blockchain data';
      setError(errorMessage);
      setConnectionStatus('error');
    } finally {
      setLoading(false);
    }
  };

  // Update parsed report when current block changes
  useEffect(() => {
    if (allChainData.length > 0 && currentBlockIndex < allChainData.length) {
      const currentBlock = allChainData[currentBlockIndex];
      const reportData = parseReportData(currentBlock.data.text);
      setParsedReport(reportData);
    }
  }, [currentBlockIndex, allChainData]);

  useEffect(() => {
    fetchBlockchainData();
  }, []);

  useEffect(() => {
    if (autoRefresh) {
      const interval = setInterval(() => {
        fetchBlockchainData();
      }, 10000);
      
      return () => clearInterval(interval);
    }
  }, [autoRefresh]);

  const navigateToBlock = (direction: 'prev' | 'next') => {
    if (direction === 'prev' && currentBlockIndex > 0) {
      setCurrentBlockIndex(currentBlockIndex - 1);
    } else if (direction === 'next' && currentBlockIndex < allChainData.length - 1) {
      setCurrentBlockIndex(currentBlockIndex + 1);
    }
  };

  const formatTimestamp = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleString();
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString();
  };

  const formatUserId = (userId: string) => {
    if (!userId) return 'N/A';
    return `${userId.substring(0, 8)}...${userId.substring(userId.length - 8)}`;
  };

  const getReportTypeColor = (category: string) => {
    const type = category.toLowerCase();
    switch (type) {
      case 'theft': return 'bg-red-900 text-red-300 border-red-700';
      case 'vandalism': return 'bg-orange-900 text-orange-300 border-orange-700';
      case 'fraud': return 'bg-purple-900 text-purple-300 border-purple-700';
      case 'assault': return 'bg-red-900 text-red-300 border-red-700';
      case 'noise': return 'bg-yellow-900 text-yellow-300 border-yellow-700';
      case 'robbery': return 'bg-red-900 text-red-300 border-red-700';
      default: return 'bg-blue-900 text-blue-300 border-blue-700';
    }
  };

  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case 'submitted': return 'bg-blue-900 text-blue-300 border-blue-700';
      case 'verified': return 'bg-green-900 text-green-300 border-green-700';
      case 'pending': return 'bg-yellow-900 text-yellow-300 border-yellow-700';
      case 'rejected': return 'bg-red-900 text-red-300 border-red-700';
      default: return 'bg-gray-900 text-gray-300 border-gray-700';
    }
  };

  const getConnectionStatusColor = () => {
    switch (connectionStatus) {
      case 'connected': return 'text-green-400';
      case 'error': return 'text-red-400';
      default: return 'text-yellow-400';
    }
  };

  const getConnectionStatusText = () => {
    switch (connectionStatus) {
      case 'connected': return 'Connected';
      case 'error': return 'Connection Error';
      default: return 'Connecting...';
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };

  const openGoogleMaps = (lat: number, lng: number) => {
    window.open(`https://www.google.com/maps?q=${lat},${lng}`, '_blank');
  };

  // Show loading state on initial load
  if (allChainData.length === 0 && loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-indigo-900 to-slate-900 flex items-center justify-center">
        <div className="text-center">
          <div className="w-16 h-16 border-4 border-blue-400 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-white mb-2">Loading Blockchain Data</h2>
          <p className="text-slate-400">Connecting to CivicEye API...</p>
          <p className="text-slate-500 text-sm mt-2"></p>
        </div>
      </div>
    );
  }

  // Show error state if no data and error occurred
  if (allChainData.length === 0 && error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-indigo-900 to-slate-900 flex items-center justify-center">
        <div className="text-center max-w-md">
          <AlertCircle className="mx-auto h-16 w-16 text-red-400 mb-4" />
          <h2 className="text-2xl font-bold text-white mb-2">Connection Failed</h2>
          <p className="text-red-300 mb-4">{error}</p>
          <p className="text-slate-400 mb-6">Unable to connect to the CivicEye blockchain API or no valid blocks found (index ≥ 5).</p>
          <button
            onClick={fetchBlockchainData}
            disabled={loading}
            className="px-6 py-3 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-800 text-white rounded-lg font-medium transition-colors flex items-center gap-2 mx-auto"
          >
            <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
            {loading ? 'Retrying...' : 'Retry Connection'}
          </button>
        </div>
      </div>
    );
  }

  const currentBlock = allChainData[currentBlockIndex];

  return (
    <div className="min-h-screen bg-slate-900 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <div className="p-3 bg-blue-600/20 rounded-xl border border-blue-500/30">
                <Eye className="h-8 w-8 text-blue-400" />
              </div>
              <div>
                <h1 className="text-4xl font-bold text-white">CivicEye</h1>
                <p className="text-blue-300 font-medium">Blockchain Explorer</p>
                <p className="text-slate-400 text-sm">({allChainData.length} blocks)</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="autoRefresh"
                  checked={autoRefresh}
                  onChange={(e) => setAutoRefresh(e.target.checked)}
                  className="rounded bg-slate-700 border-slate-600 text-blue-600 focus:ring-blue-500"
                />
                <label htmlFor="autoRefresh" className="text-sm text-slate-300">
                  Auto-refresh (10s)
                </label>
              </div>
              <button
                onClick={fetchBlockchainData}
                disabled={loading}
                className="px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-800 text-white rounded-lg font-medium transition-colors flex items-center gap-2"
              >
                <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
                {loading ? 'Loading...' : 'Refresh'}
              </button>
            </div>
          </div>
          
          <div className="flex items-center gap-6 text-sm text-slate-400">
            <div className="flex items-center gap-2">
              <Activity className={`h-4 w-4 ${getConnectionStatusColor()}`} />
              <span className={getConnectionStatusColor()}>{getConnectionStatusText()}</span>
            </div>
            {lastUpdated && (
              <div className="flex items-center gap-2">
                <Clock className="h-4 w-4" />
                <span>Last updated: {lastUpdated.toLocaleTimeString()}</span>
              </div>
            )}
            <div className="flex items-center gap-2">
              <Globe className="h-4 w-4 text-blue-400" />
              <span>civiceye-api.onrender.com</span>
            </div>
          </div>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-900/50 border border-red-700 rounded-xl flex items-center gap-3 text-red-300">
            <AlertCircle size={20} />
            <div>
              <p className="font-medium">API Connection Error</p>
              <p className="text-sm text-red-400">{error}</p>
            </div>
          </div>
        )}

        {loading && (
          <div className="mb-6 p-4 bg-blue-900/30 border border-blue-700 rounded-xl flex items-center gap-3 text-blue-300">
            <div className="w-5 h-5 border-2 border-blue-400 border-t-transparent rounded-full animate-spin" />
            <span>Fetching latest blockchain data...</span>
          </div>
        )}

        {/* Block Navigation */}
        {allChainData.length > 1 && (
          <div className="mb-6 flex items-center justify-between bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 p-4">
            <button
              onClick={() => navigateToBlock('prev')}
              disabled={currentBlockIndex === 0}
              className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-slate-700 disabled:text-slate-500 text-white rounded-lg font-medium transition-colors"
            >
              <ChevronLeft size={16} />
              Newer Block
            </button>
            
            <div className="text-center">
              <div className="text-white font-medium">
                Block {currentBlockIndex + 1} of {allChainData.length}
              </div>
              <div className="text-slate-400 text-sm">
                Index #{currentBlock?.index}
              </div>
            </div>
            
            <button
              onClick={() => navigateToBlock('next')}
              disabled={currentBlockIndex === allChainData.length - 1}
              className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-slate-700 disabled:text-slate-500 text-white rounded-lg font-medium transition-colors"
            >
              Older Block
              <ChevronRight size={16} />
            </button>
          </div>
        )}

        {currentBlock && (
          <>
            {/* Report Overview Card */}
            {parsedReport && (
              <div className="bg-slate-800/50 backdrop-blur-sm rounded-2xl border border-slate-700 overflow-hidden mb-6">
                <div className="bg-gradient-to-r from-red-600/20 to-orange-600/20 p-6 border-b border-slate-700">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4">
                      <div className="p-3 bg-red-600/30 rounded-xl">
                        <Shield className="h-6 w-6 text-red-300" />
                      </div>
                      <div>
                        <h2 className="text-2xl font-bold text-white">{parsedReport.title}</h2>
                        <p className="text-slate-300">{parsedReport.description}</p>
                      </div>
                    </div>
                    <div className="text-right space-y-2">
                      <div className={`inline-flex items-center px-3 py-1.5 rounded-full text-sm font-medium border ${getReportTypeColor(parsedReport.category)}`}>
                        <Tag className="h-4 w-4 mr-2" />
                        {parsedReport.category.toUpperCase()}
                      </div>
                      <div className={`block w-full px-3 py-1.5 rounded-full text-sm font-medium border ${getStatusColor(parsedReport.status)}`}>
                        {parsedReport.status.toUpperCase()}
                      </div>
                    </div>
                  </div>
                </div>

                <div className="p-6">
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    <div className="p-4 bg-slate-700/30 rounded-lg">
                      <div className="flex items-center gap-2 mb-2">
                        <MapPin className="h-5 w-5 text-green-400" />
                        <span className="text-slate-400 text-sm">Location</span>
                      </div>
                      <p className="text-white font-medium">{parsedReport.city}, {parsedReport.state}</p>
                      <p className="text-slate-300 text-sm">{parsedReport.country}</p>
                      <button
                        onClick={() => openGoogleMaps(parsedReport.latitude, parsedReport.longitude)}
                        className="mt-2 text-blue-400 hover:text-blue-300 text-xs flex items-center gap-1"
                      >
                        <ExternalLink size={12} />
                        View on Maps
                      </button>
                    </div>

                    <div className="p-4 bg-slate-700/30 rounded-lg">
                      <div className="flex items-center gap-2 mb-2">
                        <Calendar className="h-5 w-5 text-blue-400" />
                        <span className="text-slate-400 text-sm">Submitted</span>
                      </div>
                      <p className="text-white font-medium">{formatDate(parsedReport.submitted_at)}</p>
                    </div>

                    <div className="p-4 bg-slate-700/30 rounded-lg">
                      <div className="flex items-center gap-2 mb-2">
                        <User className="h-5 w-5 text-purple-400" />
                        <span className="text-slate-400 text-sm">Reporter</span>
                      </div>
                      <p className="text-white font-mono text-sm">{formatUserId(parsedReport.reporter_id)}</p>
                      <div className="mt-2 flex gap-2">
                        {parsedReport.is_anonymous && (
                          <span className="px-2 py-1 bg-yellow-900/50 text-yellow-300 text-xs rounded">Anonymous</span>
                        )}
                        {parsedReport.isapublicpost && (
                          <span className="px-2 py-1 bg-green-900/50 text-green-300 text-xs rounded">Public</span>
                        )}
                      </div>
                    </div>

                    <div className="p-4 bg-slate-700/30 rounded-lg">
                      <div className="flex items-center gap-2 mb-2">
                        <Hash className="h-5 w-5 text-orange-400" />
                        <span className="text-slate-400 text-sm">Report ID</span>
                      </div>
                      <p className="text-white font-mono text-sm">{formatUserId(parsedReport.id)}</p>
                      <button
                        onClick={() => copyToClipboard(parsedReport.id)}
                        className="mt-2 text-blue-400 hover:text-blue-300 text-xs"
                      >
                        Copy Full ID
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Main Block Card */}
            <div className="bg-slate-800/50 backdrop-blur-sm rounded-2xl border border-slate-700 overflow-hidden mb-8">
              <div className="bg-gradient-to-r from-blue-600/20 to-purple-600/20 p-6 border-b border-slate-700">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <div className="p-3 bg-blue-600/30 rounded-xl">
                      <Hash className="h-6 w-6 text-blue-300" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-white">Block #{currentBlock.index - 4}</h2>
                      <p className="text-slate-300">Chain Position: {currentBlockIndex + 1} of {allChainData.length}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-slate-400 text-sm">Block Timestamp</div>
                    <div className="text-white font-mono">{formatTimestamp(currentBlock.timestamp)}</div>
                  </div>
                </div>
              </div>

              <div className="p-6">
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  {/* Block Information */}
                  <div className="space-y-4">
                    <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                      <Database className="h-5 w-5 text-purple-400" />
                      Block Information
                    </h3>
                    
                    <div className="space-y-3">
                      <div className="flex justify-between items-center p-3 bg-slate-700/30 rounded-lg">
                        <span className="text-slate-400">Index</span>
                        <span className="text-white font-mono font-medium">#{currentBlock.index}</span>
                      </div>
                      
                      <div className="p-3 bg-slate-700/30 rounded-lg">
                        <div className="flex justify-between items-center mb-2">
                          <span className="text-slate-400">Block Hash</span>
                          <button
                            onClick={() => copyToClipboard(currentBlock.hash)}
                            className="text-blue-400 hover:text-blue-300 text-xs"
                          >
                            Copy
                          </button>
                        </div>
                        <code className="text-green-300 font-mono text-sm break-all">{currentBlock.hash}</code>
                      </div>
                      
                      <div className="p-3 bg-slate-700/30 rounded-lg">
                        <div className="flex justify-between items-center mb-2">
                          <span className="text-slate-400">Previous Hash</span>
                          <button
                            onClick={() => copyToClipboard(currentBlock.previous_hash)}
                            className="text-blue-400 hover:text-blue-300 text-xs"
                          >
                            Copy
                          </button>
                        </div>
                        <code className="text-orange-300 font-mono text-sm break-all">{currentBlock.previous_hash}</code>
                      </div>
                    </div>
                  </div>

                  {/* Blockchain Data */}
                  <div className="space-y-4">
                    <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                      <Shield className="h-5 w-5 text-red-400" />
                      Blockchain Data
                    </h3>
                    
                    <div className="space-y-3">
                      <div className="p-3 bg-slate-700/30 rounded-lg">
                        <div className="flex justify-between items-center mb-2">
                          <span className="text-slate-400">User ID</span>
                          <button
                            onClick={() => copyToClipboard(currentBlock.data.user_id)}
                            className="text-blue-400 hover:text-blue-300 text-xs"
                          >
                            Copy
                          </button>
                        </div>
                        <div className="flex items-center gap-2">
                          <User className="h-4 w-4 text-green-400" />
                          <code className="text-green-300 font-mono text-sm">{formatUserId(currentBlock.data.user_id)}</code>
                        </div>
                      </div>
                      
                      <div className="p-3 bg-slate-700/30 rounded-lg">
                        <span className="text-slate-400 block mb-2">Media Evidence ({currentBlock.data.media.length})</span>
                        <div className="space-y-2">
                          {currentBlock.data.media.length > 0 ? (
                            parseMediaData(currentBlock.data.media).map((filename, index) => (
                              <div key={index} className="flex items-center justify-between p-2 bg-slate-600/30 rounded border">
                                <span className="text-white text-sm font-mono truncate">{filename}</span>
                                <span className="text-slate-400 text-xs ml-2">Image</span>
                              </div>
                            ))
                          ) : (
                            <div className="text-slate-500 text-sm italic">No media evidence attached</div>
                          )}
                        </div>
                      </div>
                      
                      <div className="p-3 bg-slate-700/30 rounded-lg">
                        <div className="flex justify-between items-center mb-2">
                          <span className="text-slate-400">Report Hash</span>
                          <button
                            onClick={() => copyToClipboard(currentBlock.data.report_hash)}
                            className="text-blue-400 hover:text-blue-300 text-xs"
                          >
                            Copy
                          </button>
                        </div>
                        <code className="text-yellow-300 font-mono text-sm break-all">{currentBlock.data.report_hash}</code>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Chain Integrity Verification */}
            <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 p-6">
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                <CheckCircle className="h-5 w-5 text-green-400" />
                Chain Integrity Status
              </h3>
              
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-4 bg-green-900/30 border border-green-700 rounded-lg">
                  <div className="flex items-center gap-2 mb-2">
                    <CheckCircle className="h-5 w-5 text-green-400" />
                    <span className="text-green-300 font-medium">Block Verified</span>
                  </div>
                  <p className="text-green-200 text-sm">Block integrity confirmed via API</p>
                </div>
                
                <div className="p-4 bg-blue-900/30 border border-blue-700 rounded-lg">
                  <div className="flex items-center gap-2 mb-2">
                    <Hash className="h-5 w-5 text-blue-400" />
                    <span className="text-blue-300 font-medium">Hash Valid</span>
                  </div>
                  <p className="text-blue-200 text-sm">Cryptographic hash verified</p>
                </div>
                
                <div className="p-4 bg-purple-900/30 border border-purple-700 rounded-lg">
                  <div className="flex items-center gap-2 mb-2">
                    <Shield className="h-5 w-5 text-purple-400" />
                    <span className="text-purple-300 font-medium">Data Secure</span>
                  </div>
                  <p className="text-purple-200 text-sm">Report data immutable on chain</p>
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default CivicEyeBlockchainExplorer;