'use client'

import React, { useState, useEffect, useRef } from 'react';
import { supabase } from '../../../lib/supabaseClient';
import { Menu, X, Plus, Send, MessageCircle, MoreVertical, Trash2, Bot, User, Settings, Home, Inbox, BarChart3, Copy, RefreshCw, AlertCircle, Mic, MicOff, Paperclip } from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import { useParams } from 'next/navigation';
import { log } from 'console';
import Image from 'next/image';

interface Message {
  text: string;
  isUser: boolean;
  timestamp: string;
  id?: string;
  type?: 'text' | 'loading' | 'error';
    logo?: boolean; 
}

interface ChatSession {
  id: string;
  title: string;
  created_at: string;
  last_active_at: string;
  messageCount?: number;
}

// Menu items for sidebar
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

// Message Bubble Component
interface MessageBubbleProps {
  message: Message;
  onCopy: (content: string) => void;
  onDelete?: (id: string) => void;
}

const MessageBubble: React.FC<MessageBubbleProps> = ({ message, onCopy, onDelete }) => {
  const isBot = !message.isUser;
  
  return (
    <div className={`flex items-start gap-3 p-4 ${message.isUser ? 'flex-row-reverse' : ''}`}>
    {/* Avatar */}
<div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${
  isBot 
    ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30' 
    : 'bg-slate-600/50 text-slate-300 border border-slate-600/50'
}`}>
  {isBot ? (
    message.logo ? (
      <Image src='/logo1.png' priority={true} alt='CivicEye Logo' height={32} width={32} className="w-4 h-4 object-contain" />
    ) : (
      <Image src='/logo1.png' priority={true} alt='CivicEye Logo' height={32} width={32} className="w-4 h-4 object-contain"/>
    )
  ) : (
    <User className="w-4 h-4" />
  )}
</div>

      {/* Message Content */}
      <div className={`flex-1 max-w-[80%] ${message.isUser ? 'flex flex-col items-end' : ''}`}>
        <div className={`relative group backdrop-blur-sm ${
          isBot 
            ? 'bg-slate-800/60 border border-slate-700/50' 
            : 'bg-blue-600/20 border border-blue-500/30'
        } rounded-2xl px-4 py-3 shadow-lg`}>
          
          {message.type === 'loading' ? (
            <div className="flex items-center gap-3">
              <div className="flex space-x-1">
                <div className="w-2 h-2 bg-blue-400 rounded-full animate-bounce"></div>
                <div className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '0.1s' }}></div>
                <div className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '0.2s' }}></div>
              </div>
              <span className="text-slate-400 text-sm">Analyzing your query...</span>
            </div>
          ) : message.type === 'error' ? (
            <div className="flex items-center gap-2 text-red-400">
              <AlertCircle className="w-4 h-4" />
              <span className="text-sm">{message.text}</span>
            </div>
          ) : message.isUser ? (
            <p className="text-slate-100 text-sm leading-relaxed">{message.text}</p>
          ) : (
            <div className="prose prose-invert max-w-none text-sm">
              <ReactMarkdown
                components={{
                  h1: ({ children }) => <h1 className="text-orange-400 text-lg font-bold mb-2">{children}</h1>,
                  h2: ({ children }) => <h2 className="text-orange-400 text-base font-bold mb-2">{children}</h2>,
                  h3: ({ children }) => <h3 className="text-orange-400 text-sm font-bold mb-1">{children}</h3>,
                  code: ({ children }) => <code className="bg-black/30 text-white px-1 py-0.5 rounded text-xs font-mono">{children}</code>,
                  pre: ({ children }) => <pre className="bg-black/30 p-3 rounded-lg text-xs font-mono overflow-x-auto">{children}</pre>,
                  blockquote: ({ children }) => <blockquote className="border-l-4 border-orange-400 pl-4 italic text-orange-400">{children}</blockquote>,
                  strong: ({ children }) => <strong className="text-orange-400 font-bold">{children}</strong>,
                  em: ({ children }) => <em className="text-orange-400 italic">{children}</em>,
                  a: ({ href, children }) => <a href={href} className="text-orange-400 underline" target="_blank" rel="noopener noreferrer">{children}</a>,
                  ul: ({ children }) => <ul className="list-disc list-inside space-y-1">{children}</ul>,
                  ol: ({ children }) => <ol className="list-decimal list-inside space-y-1">{children}</ol>,
                  li: ({ children }) => <li className="text-slate-100">{children}</li>,
                }}
              >
                {message.text}
              </ReactMarkdown>
            </div>
          )}

          {/* Message Actions */}
          {message.type !== 'loading' && (
            <div className="absolute -top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
              <div className="flex items-center gap-1 bg-slate-700 rounded-lg p-1 shadow-lg">
                <button
                  onClick={() => onCopy(message.text)}
                  className="p-1 text-slate-400 hover:text-slate-100 transition-colors"
                  title="Copy"
                >
                  <Copy className="w-3 h-3" />
                </button>
                {onDelete && message.id && (
                  <button
                    onClick={() => onDelete(message.id!)}
                    className="p-1 text-slate-400 hover:text-red-400 transition-colors"
                    title="Delete"
                  >
                    <Trash2 className="w-3 h-3" />
                  </button>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Timestamp */}
        <div className={`text-xs text-slate-500 mt-1 ${message.isUser ? 'text-right' : ''}`}>
          {new Date(message.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
        </div>
      </div>
    </div>
  );
};

const ChatbotPage: React.FC = () => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [messageInput, setMessageInput] = useState('');
  const [chatHistory, setChatHistory] = useState<ChatSession[]>([]);
  const [currentChatId, setCurrentChatId] = useState<string | null>(null);
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [isDropdownOpen, setIsDropdownOpen] = useState<string | null>(null);
  const [isListening, setIsListening] = useState(false);
  const [copySuccess, setCopySuccess] = useState(false);
  const [userId, setUserId] = useState<string | null>(null);
  
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const recognitionRef = useRef<any>(null);

  useEffect(() => {
    initializeChat();
    loadChatHistory();
    
    // Cleanup speech recognition on unmount
    return () => {
      if (recognitionRef.current) {
        recognitionRef.current.stop();
      }
    };
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsDropdownOpen(null);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Auto-resize textarea
  useEffect(() => {
    if (inputRef.current) {
      inputRef.current.style.height = 'auto';
      inputRef.current.style.height = Math.min(inputRef.current.scrollHeight, 128) + 'px';
    }
  }, [messageInput]);

 const initializeChat = () => {
  const initialMessage: Message = {
    text: 'Hello! I am your CivicEye AI assistant. I can help you with queries related to Indian Criminal Law and Constitutional matters. How can I help you today?',
    isUser: false,
    timestamp: new Date().toISOString(),
    id: '1',
    type: 'text',
    logo: true // Add this flag to indicate this message should show logo
  };
    setMessages([initialMessage]);
    createNewChatSession();
  };

  const createNewChatSession = async () => {
    try {
      const { data, error } = await supabase
        .from('chat_sessions')
        .insert({
          title: 'New Legal Consultation',
          created_at: new Date().toISOString(),
          last_active_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (error) throw error;
      
      setCurrentChatId(data.id.toString());
      await loadChatHistory();
    } catch (error) {
      console.error('Error creating chat session:', error);
    }
  };

  useEffect(() => {
    const fetchUserId = async () => {
      const { data, error } = await supabase.auth.getSession();
      if (error) {
        console.error("Failed to get user:", error.message);
        setUserId(null);
      } else {
        setUserId(data?.session?.user?.id || null);
      }
    };
    fetchUserId();
  }, []);

  const loadChatHistory = async () => {
    setIsLoadingHistory(true);
    try {
      if (!userId) return;
      const { data, error } = await supabase
        .from('chat_messages')
        .select('*')
        .eq('user_id', userId)
        .limit(20);

      if (error) throw error;
      setChatHistory(data || []);
    } catch (error) {
      console.log('Error loading chat history:', error);
    } finally {
      setIsLoadingHistory(false);
    }
  };

  const loadChatMessages = async (chatId: string) => {
    try {
      const { data, error } = await supabase
        .from('chat_messages')
        .select('*')
        .eq('chat_session_id', chatId)
        .order('created_at', { ascending: true });

      if (error) throw error;

      const initialMessage: Message = {
        text: 'Hello! I am your CivicEye AI assistant. How can I help you today?',
        isUser: false,
        timestamp: new Date().toISOString(),
        id: '1',
        type: 'text'
      };

      const loadedMessages: Message[] = [
        initialMessage,
        ...(data || []).map((msg: any) => ({
          text: msg.message,
          isUser: msg.is_user,
          timestamp: msg.created_at,
          id: msg.id.toString(),
          type: 'text' as 'text'
        }))
      ];

      setMessages(loadedMessages);
      setCurrentChatId(chatId);
      setIsSidebarOpen(false);
    } catch (error) {
      console.error('Error loading chat messages:', error);
    }
  };

  const saveChatMessage = async (message: string, isUser: boolean) => {
    if (!currentChatId) return;

    try {
      await supabase.from('chat_messages').insert({
        chat_session_id: currentChatId,
        message: message,
        is_user: isUser,
        created_at: new Date().toISOString(),
      });

      await supabase
        .from('chat_sessions')
        .update({ last_active_at: new Date().toISOString() })
        .eq('id', currentChatId);

      if (isUser && messages.length <= 2) {
        const title = message.length > 30 ? `${message.substring(0, 30)}...` : message;
        await supabase
          .from('chat_sessions')
          .update({ title })
          .eq('id', currentChatId);
      }
    } catch (error) {
      console.error('Error saving message:', error);
    }
  };

  const deleteChat = async (chatId: string) => {
    try {
      await supabase
        .from('chat_messages')
        .delete()
        .eq('chat_session_id', chatId);

      await supabase
        .from('chat_sessions')
        .delete()
        .eq('id', chatId);

      if (currentChatId === chatId) {
        setMessages([]);
        initializeChat();
      }

      await loadChatHistory();
    } catch (error) {
      console.error('Error deleting chat:', error);
    }
  };

  const sendMessage = async () => {
    if (messageInput.trim().length === 0 || isLoading) return;

    const userMessage = messageInput.trim();
    const newUserMessage: Message = {
      text: userMessage,
      isUser: true,
      timestamp: new Date().toISOString(),
      id: Date.now().toString(),
      type: 'text'
    };

    const loadingMessage: Message = {
      text: '',
      isUser: false,
      timestamp: new Date().toISOString(),
      id: (Date.now() + 1).toString(),
      type: 'loading'
    };

    setMessages(prev => [...prev, newUserMessage, loadingMessage]);
    setMessageInput('');
    setIsLoading(true);

    await saveChatMessage(userMessage, true);

    try {
      const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL || '';
      const response = await fetch(`${baseUrl}/chatbot/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: userMessage }),
      });

      let botMessage: Message;
      
      if (response.ok) {
        const data = await response.json();
        botMessage = {
          text: data.answer || 'I received your message but couldn\'t generate a proper response.',
          isUser: false,
          timestamp: new Date().toISOString(),
          id: (Date.now() + 2).toString(),
          type: 'text'
        };
      } else {
        const errorText = response.status === 404 
          ? 'API endpoint not found. Please check your configuration.' 
          : `Server error (${response.status}). Please try again later.`;
        
        botMessage = {
          text: errorText,
          isUser: false,
          timestamp: new Date().toISOString(),
          id: (Date.now() + 2).toString(),
          type: 'error'
        };
      }

      setMessages(prev => prev.filter(msg => msg.type !== 'loading').concat([botMessage]));
      await saveChatMessage(botMessage.text, false);
    } catch (error) {
      console.error('Chat API error:', error);
      const errorMessage: Message = {
        text: 'Network error. Please check your connection and try again.',
        isUser: false,
        timestamp: new Date().toISOString(),
        id: (Date.now() + 2).toString(),
        type: 'error'
      };
      
      setMessages(prev => prev.filter(msg => msg.type !== 'loading').concat([errorMessage]));
      await saveChatMessage(errorMessage.text, false);
    } finally {
      setIsLoading(false);
    }

    await loadChatHistory();
  };

  const handleVoiceInput = () => {
    // Check for browser support
    const SpeechRecognitionConstructor =
      (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    
    if (!SpeechRecognitionConstructor) {
      alert('Speech recognition is not supported in this browser. Please try using Chrome or Edge.');
      return;
    }

    if (isListening) {
      // Stop listening
      if (recognitionRef.current) {
        recognitionRef.current.stop();
      }
      setIsListening(false);
      return;
    }

    // Start listening
    const recognition = new SpeechRecognitionConstructor();
    recognitionRef.current = recognition;
    
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.lang = 'en-IN';
    
    recognition.onstart = () => {
      setIsListening(true);
    };
    
    recognition.onend = () => {
      setIsListening(false);
      recognitionRef.current = null;
    };
    
    recognition.onresult = (event: any) => {
      if (event.results && event.results[0] && event.results[0][0]) {
        const transcript = event.results[0][0].transcript;
        setMessageInput(prev => prev + (prev ? ' ' : '') + transcript);
      }
    };
    
    recognition.onerror = (event: any) => {
      console.error('Speech recognition error:', event.error);
      setIsListening(false);
      recognitionRef.current = null;
      
      if (event.error === 'not-allowed') {
        alert('Microphone access denied. Please allow microphone access and try again.');
      } else if (event.error === 'no-speech') {
        alert('No speech detected. Please try again.');
      }
    };
    
    try {
      recognition.start();
    } catch (error) {
      console.error('Failed to start speech recognition:', error);
      setIsListening(false);
    }
  };

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const formatTimestamp = (timestamp: string): string => {
    try {
      const dateTime = new Date(timestamp);
      const now = new Date();
      const difference = now.getTime() - dateTime.getTime();

      const days = Math.floor(difference / (1000 * 60 * 60 * 24));
      const hours = Math.floor(difference / (1000 * 60 * 60));
      const minutes = Math.floor(difference / (1000 * 60));

      if (days > 0) return `${days}d ago`;
      if (hours > 0) return `${hours}h ago`;
      if (minutes > 0) return `${minutes}m ago`;
      return 'Just now';
    } catch {
      return 'Unknown';
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const handleCopyMessage = async (content: string) => {
    try {
      await navigator.clipboard.writeText(content);
      setCopySuccess(true);
      setTimeout(() => setCopySuccess(false), 2000);
    } catch (error) {
      console.error('Failed to copy message:', error);
      // Fallback for browsers that don't support clipboard API
      const textArea = document.createElement('textarea');
      textArea.value = content;
      document.body.appendChild(textArea);
      textArea.select();
      try {
        document.execCommand('copy');
        setCopySuccess(true);
        setTimeout(() => setCopySuccess(false), 2000);
      } catch (err) {
        console.error('Fallback copy failed:', err);
      }
      document.body.removeChild(textArea);
    }
  };

  const handleDeleteMessage = (messageId: string) => {
    setMessages(prev => prev.filter(msg => msg.id !== messageId));
  };

  const handleNewChat = () => {
    setMessages([]);
    initializeChat();
    setIsSidebarOpen(false);
  };

  return (
    <div className="flex h-screen bg-slate-900">
      {/* Sidebar Overlay for mobile */}
      {isSidebarOpen && (
        <div 
          className="fixed inset-0 bg-black/50 z-40 lg:hidden"
          onClick={() => setIsSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <div className={`fixed inset-y-0 left-0 z-50 w-80 bg-slate-800/90 backdrop-blur-sm border-r border-slate-700/50 transform ${isSidebarOpen ? 'translate-x-0' : '-translate-x-full'} transition-transform duration-300 ease-in-out lg:translate-x-0 lg:static lg:inset-0`}>
  <div className="flex h-full flex-col">
    {/* Logo Section - Now perfectly aligned with main header */}
    <div className="bg-slate-800/50 backdrop-blur-sm border-b border-slate-700/50 px-6 py-4 flex-shrink-0">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-blue-500/20 rounded-full flex items-center justify-center">
            <Image src='/logo1.png' priority={true} alt='logo' height={100} width={100} />
          </div>
          <div>
            <h1 className="text-lg font-semibold text-slate-100">CivicEye</h1>
            <p className="text-sm text-slate-400">Civic Monitoring System</p>
          </div>
        </div>
        <button
          className="lg:hidden text-slate-300 p-2 rounded-md hover:bg-slate-700/50 transition-colors"
          onClick={() => setIsSidebarOpen(false)}
        >
          <X className="h-5 w-5" />
        </button>
      </div>
    </div>
    
          
          {/* Navigation Menu */}
          <nav className="px-4 py-6 border-b border-slate-700/50">
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

          {/* Chat History */}
          <div className="flex-1 px-4 py-4 overflow-y-auto">
            <div className="flex items-center justify-between mb-4">
              <div className="px-3 py-2 text-xs font-semibold text-slate-400 uppercase tracking-wider">
                Chat History
              </div>
              <button
                onClick={handleNewChat}
                className="p-1 text-slate-400 hover:text-slate-100 hover:bg-slate-700/50 rounded transition-colors"
                title="New Chat"
              >
                <Plus className="w-4 h-4" />
              </button>
            </div>
            
            {isLoadingHistory ? (
              <div className="flex justify-center items-center h-32">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-400"></div>
              </div>
            ) : chatHistory.length === 0 ? (
              <div className="text-center text-slate-400 mt-8">
                No chat history
              </div>
            ) : (
              <div className="space-y-2">
                {chatHistory.map((chat) => {
                  const isCurrentChat = chat.id === currentChatId;
                  return (
                    <div
                      key={chat.id}
                      className={`p-3 rounded-lg cursor-pointer transition-colors group ${
                        isCurrentChat
                          ? 'bg-slate-700/50 border border-slate-600/50'
                          : 'hover:bg-slate-700/30'
                      }`}
                      onClick={() => !isCurrentChat && loadChatMessages(chat.id)}
                    >
                      <div className="flex items-start justify-between">
                        <div className="flex items-center space-x-3 flex-1 min-w-0">
                          <div className={`rounded-full p-2 flex-shrink-0 ${isCurrentChat ? 'bg-blue-500/20 text-blue-400' : 'bg-slate-600/50 text-slate-400'}`}>
                            <MessageCircle className="h-3 w-3" />
                          </div>
                          <div className="flex-1 min-w-0">
                            <h4 className={`text-sm font-medium truncate ${isCurrentChat ? 'text-slate-100' : 'text-slate-300'}`}>
                              {chat.title || 'Untitled Chat'}
                            </h4>
                            <p className={`text-xs truncate mt-1 ${isCurrentChat ? 'text-slate-400' : 'text-slate-500'}`}>
                              {formatTimestamp(chat.last_active_at || chat.created_at)}
                            </p>
                          </div>
                        </div>
                        <div className="relative opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0" ref={dropdownRef}>
                          <button
                            className="p-1 text-slate-400 hover:text-slate-100 rounded transition-colors"
                            onClick={(e) => {
                              e.stopPropagation();
                              setIsDropdownOpen(isDropdownOpen === chat.id ? null : chat.id);
                            }}
                          >
                            <MoreVertical className="h-3 w-3" />
                          </button>
                          {isDropdownOpen === chat.id && (
                            <div className="absolute right-0 mt-1 w-32 bg-slate-700 rounded-md shadow-lg z-10 border border-slate-600">
                              <button
                                className="flex items-center w-full px-3 py-2 text-sm text-red-400 hover:bg-slate-600 rounded-md transition-colors"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  deleteChat(chat.id);
                                  setIsDropdownOpen(null);
                                }}
                              >
                                <Trash2 className="h-3 w-3 mr-2" />
                                Delete
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </div>



      {/* Main Content */}
      <div className="flex-1 flex flex-col min-h-0">
        {/* Header */}
        <div className="bg-slate-800/50 backdrop-blur-sm border-b border-slate-700/50 px-6 py-4 flex-shrink-0">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <button
                className="lg:hidden text-slate-300 p-2 rounded-md hover:bg-slate-700/50 transition-colors"
                onClick={() => setIsSidebarOpen(!isSidebarOpen)}
              >
                <Menu className="h-5 w-5" />
              </button>
              <div className="w-10 h-10 bg-blue-500/20 rounded-full flex items-center justify-center">
                 <Image src='/logo1.png' priority={true} alt='logo' height={100} width={100} />
              </div>
              <div>
                <h1 className="text-lg font-semibold text-slate-100">Lawgic</h1>
                <p className="text-sm text-slate-400">
                  {isLoading ? 'Processing your query...' : 'Online • Ready to help with legal queries'}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <div className="text-xs text-slate-400 text-right hidden sm:block">
                <div>Indian Criminal Law</div>
                <div>Constitutional Matters</div>
              </div>
              <button
                onClick={handleNewChat}
                className="p-2 text-slate-400 hover:text-slate-100 hover:bg-slate-700/50 rounded-lg transition-colors"
                title="New Chat"
              >
                <Plus className="h-4 w-4" />
              </button>
              <button className="p-2 text-slate-400 hover:text-slate-100 hover:bg-slate-700/50 rounded-lg transition-colors">
                <Settings className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>

        {/* Messages Area */}
        <div className="flex-1 overflow-y-auto">
          {messages.map((message, index) => (
            <MessageBubble
              key={message.id || index}
              message={message}
              onCopy={handleCopyMessage}
              onDelete={handleDeleteMessage}
            />
          ))}
          <div ref={messagesEndRef} />
        </div>

        {/* Copy Success Notification */}
        {copySuccess && (
          <div className="fixed top-4 right-4 bg-green-500/20 border border-green-500/30 text-green-400 px-4 py-2 rounded-lg shadow-lg z-50">
            <div className="flex items-center gap-2">
              <Copy className="w-4 h-4" />
              <span className="text-sm">Message copied to clipboard!</span>
            </div>
          </div>
        )}

        {/* Input Area */}
        <div className="bg-slate-800/50 backdrop-blur-sm border-t border-slate-700/50 p-4 flex-shrink-0">
          <div className="max-w-4xl mx-auto">
            <div className="flex items-end gap-3">
              <div className="flex-1 relative">
                <textarea
                  ref={inputRef}
                  value={messageInput}
                  onChange={(e) => setMessageInput(e.target.value)}
                  onKeyPress={handleKeyPress}
                  placeholder="Ask me about Indian Criminal Law, Constitutional matters, legal procedures... (Press Enter to send, Shift+Enter for new line)"
                  className="w-full bg-slate-700/50 border border-slate-600/50 rounded-2xl px-4 py-3 pr-12 text-slate-100 placeholder-slate-400 resize-none min-h-[50px] max-h-32 focus:outline-none focus:border-blue-500/50 focus:bg-slate-700/70 transition-colors"
                  rows={1}
                  disabled={isLoading}
                  maxLength={2000}
                />
                <button
                  onClick={() => {
                    // File attachment functionality would go here
                    alert('File attachment feature coming soon!');
                  }}
                  className="absolute right-3 bottom-3 p-1 text-slate-400 hover:text-slate-100 transition-colors"
                  title="Attach legal document"
                  disabled={isLoading}
                >
                  <Paperclip className="w-4 h-4" />
                </button>
              </div>
              
              <button
                onClick={handleVoiceInput}
                className={`p-3 rounded-xl transition-colors flex-shrink-0 ${
                  isListening 
                    ? 'bg-red-500/20 text-red-400 border border-red-500/30 animate-pulse' 
                    : 'bg-slate-700/50 text-slate-400 hover:text-slate-100 border border-slate-600/50 hover:border-slate-500/50'
                }`}
                title={isListening ? "Stop listening" : "Voice input"}
                disabled={isLoading}
              >
                {isListening ? <MicOff className="w-4 h-4" /> : <Mic className="w-4 h-4" />}
              </button>
              
              <button
                onClick={sendMessage}
                disabled={!messageInput.trim() || isLoading}
                className="p-3 bg-blue-600 hover:bg-blue-700 disabled:bg-slate-600 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-xl transition-colors shadow-lg flex-shrink-0"
                title="Send legal query"
              >
                {isLoading ? (
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                ) : (
                  <Send className="w-4 h-4" />
                )}
              </button>
            </div>
            
            <div className="flex items-center justify-between mt-2 text-xs text-slate-500">
              <span>
                {isLoading 
                  ? 'Legal assistant is analyzing your query...' 
                  : 'Ask about criminal law, constitutional matters, or legal procedures'}
              </span>
              <span className="hidden sm:inline">
                {messageInput.length}/2000 characters
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ChatbotPage;