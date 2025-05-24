'use client';

import React, { useEffect, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Shield, Users, Lock, Brain, Scale, Bell, ChevronDown, ExternalLink } from 'lucide-react';
import Image from 'next/image';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabaseClient'

export default function Home() {
  const [isLoaded, setIsLoaded] = useState(false);
  
  const [user, setUser] = useState<any>(null)

  const router = useRouter()
 useEffect(() => {
    const getSession = async () => {
      const { data, error } = await supabase.auth.getSession()
      
      if (data?.session?.user) {
        setUser(data.session.user)
        
      } else {
        setUser(null)
      }
    }

    getSession()

    

    
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user || null)
    })

    return () => {
      listener?.subscription.unsubscribe()
    }
  }, [])

  useEffect(() => {
  console.log("User changed:", user);
}, [user])

useEffect(() => {
  setIsLoaded(true); 
}, []);
  const handleLogout = async () => {
    await supabase.auth.signOut()
    setUser(null)
    router.push('/')
  }

  return (
    <div className="min-h-screen bg-[#1e3b8a] overflow-hidden">


      {/* Gradient Background */}
      <div className="fixed inset-0 z-[-1]">
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-primary/30 via-background to-background"></div>
        <div className="absolute top-0 left-0 w-full h-full bg-[linear-gradient(to_right,transparent,rgba(9,14,27,0.8))]"></div>
        <div className="absolute bottom-0 right-0 w-3/4 h-3/4 bg-[radial-gradient(circle,_var(--tw-gradient-stops))] from-secondary/20 via-transparent to-transparent blur-3xl"></div>
      </div>

      {/* Navigation */}
      <nav className="fixed top-0 left-0 right-0 z-50 p-4   backdrop-blur-lg border-b border-white/5">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center">
            <Image src='/logo1.png' priority={true} alt='logo' height={100} width={100} />
            <span className="font-bold text-xl -ml-1  bg-clip-text text-foreground">CivicEye</span>
          </div>
          <div className="hidden md:flex items-center gap-8">
            <a href="#features" className="text-foreground/80 hover:text-secondary transition-colors text-xl">Features</a>
            <a href="#stats" className="text-foreground/80 hover:text-secondary transition-colors text-xl">Impact</a>
            <a href="#testimonials" className="text-foreground/80 hover:text-secondary transition-colors text-xl">Testimonials</a>
          </div>
                {user ? (
        <div className="relative group flex items-center space-x-2">
          <img
            src={user.user_metadata?.avatar_url || `https://ui-avatars.com/api/?name=${user.full_name}`}
            alt="avatar"
            className="w-8 h-8 rounded-full"
          />
          <span className="text-white hidden sm:block">
            {user.user_metadata?.full_name || user.full_name}
          </span>

          <div className="relative group">
            
            <div className="absolute right-0 mt-2 w-40 bg-white text-black rounded shadow-md hidden group-hover:block z-50">
              <a
                href="/dashboard"
                className="block px-4 py-2 hover:bg-gray-100"
              >
                Dashboard
              </a>
              <a
                href="/auth/profile-edit"
                className="block px-4 py-2 hover:bg-gray-100"
              >
                Edit Profile
              </a>
              <button
                onClick={handleLogout}
                className="w-full text-left px-4 py-2 hover:bg-gray-100"
              >
                Log out
              </button>
            </div>
          </div>
        </div>
      ) : (
          <Button size="sm" className="bg-gradient-to-r from-[#3b82f6] to-[#2563eb] hover:from-secondary hover:to-primary text-foreground border-0" onClick={()=>router.push('/auth/login')}>
            Sign In
          </Button>
      )}
     
        </div>
      </nav>



      {/* Hero Section */}
      <section className="relative pt-32 pb-24 px-4 sm:px-6 lg:px-8 min-h-screen flex items-center">
        <div className="absolute inset-0">
          <div className="absolute inset-0 bg-gradient-to-b from-primary/20 via-background to-background -z-10" />
          <div className="absolute top-1/4 right-1/4 w-96 h-96 bg-gradient-to-br from-secondary/30 to-primary/30 rounded-full filter blur-3xl opacity-30 animate-pulse-slow" />
          <div className="absolute bottom-1/3 left-1/3 w-80 h-80 bg-gradient-to-tr from-primary/40 to-secondary/20 rounded-full filter blur-3xl opacity-20 animate-pulse-slow" />
        </div>

        <div className="max-w-7xl mx-auto w-full">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
            <div className={`space-y-8 ${isLoaded ? 'animate-fade-in' : 'opacity-0'}`} style={{ animationDelay: '0.2s' }}>
              <div className="inline-block px-4 py-1 rounded-full bg-gradient-to-r from-secondary/20 to-primary/20 border border-secondary/30 text-secondary">
                Secure. Anonymous. Impactful.
              </div>
              <h1 className="text-4xl sm:text-6xl font-bold tracking-tight mb-6 leading-tight">
                Empowering Voices,{' '}
                <span className="bg-gradient-to-r from-secondary via-secondary/90 to-primary-light bg-clip-text text-transparent drop-shadow-sm">Protecting Truth</span>
              </h1>
              <p className="text-xl text-muted-foreground max-w-2xl mb-8">
                Report injustice safely and anonymously. Your voice matters, and we ensure it's heard while keeping you protected.
              </p>
              <div className="flex flex-wrap gap-4">
                <Button size="lg" className="bg-gradient-to-r from-secondary to-primary text-foreground hover:opacity-90 shadow-md border-0">
                  Report Anonymously
                </Button>
                <Button
  size="lg"
  className="bg-blue-800 text-white hover:bg-blue-900 font-semibold border border-blue-900"
>
  Learn More
</Button>


              </div>
              <div className="pt-8 flex items-center gap-2 text-sm text-muted-foreground">
                <Shield className="w-4 h-4 text-secondary" />
                Your privacy is our priority. All reports are encrypted end-to-end.
              </div>
            </div>
            <div className={`relative ${isLoaded ? 'animate-fade-in' : 'opacity-0'}`} style={{ animationDelay: '0.4s' }}>
              <div className="relative mx-auto w-full max-w-md aspect-square animate-float">
                <div className="absolute inset-0 rounded-full bg-gradient-to-r from-primary/40 to-secondary/40 opacity-30 blur-2xl" />
                <div className="relative bg-gradient-to-br from-card/90 to-card/40 rounded-lg border border-white/10 p-6 shadow-lg backdrop-blur-sm">
                  <div className="absolute -top-3 -left-3 w-16 h-16 bg-gradient-to-br from-secondary/30 to-secondary/10 rounded-lg backdrop-blur-md border border-secondary/30 flex items-center justify-center">
                    <Lock className="text-secondary w-8 h-8" />
                  </div>
                  <div className="pt-8 pb-4">
                    <div className="w-full h-32 bg-gradient-to-br from-primary/30 to-primary/10 rounded-md mb-4 flex items-center justify-center backdrop-blur-sm">
                      <Users className="text-primary-light w-12 h-12" />
                    </div>
                    <div className="space-y-2">
                      <div className="h-3 bg-gradient-to-r from-white/20 to-white/5 rounded-full w-3/4" />
                      <div className="h-3 bg-gradient-to-r from-white/20 to-white/5 rounded-full w-full" />
                      <div className="h-3 bg-gradient-to-r from-white/20 to-white/5 rounded-full w-2/3" />
                    </div>
                  </div>
                  <div className="flex justify-end">
                    <div className="rounded-full bg-gradient-to-r from-secondary to-secondary/70 text-secondary-foreground px-4 py-1 text-sm font-medium">Protected</div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="absolute bottom-8 left-1/2 transform -translate-x-1/2 animate-bounce opacity-80">
  <a
    href="#features"
    className="flex flex-col items-center text-sm !text-[#60a5fa] hover:!text-[#3b82f6] transition-colors"
  >
    <span>Learn more</span>
    <ChevronDown className="w-5 h-5" />
  </a>
</div>

        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-24 px-4 sm:px-6 lg:px-8 relative">
        <div className="absolute inset-0">
          <div className="absolute inset-0 bg-gradient-to-b from-background via-primary/5 to-background -z-10" />
          <div className="absolute right-0 top-1/4 w-1/2 h-1/2 bg-gradient-to-bl from-secondary/10 to-transparent blur-3xl" />
        </div>
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16 space-y-4">
            <div className="inline-block px-4 py-1 rounded-full bg-gradient-to-r from-primary/20 to-primary/5 border border-primary/30 text-primary mb-4">
              Advanced Features
            </div>
            <h2 className="text-3xl sm:text-4xl font-bold bg-gradient-to-r from-foreground to-foreground/80 bg-clip-text text-transparent">How CivicEye Works</h2>
            <p className="text-muted-foreground max-w-2xl mx-auto">
              Our platform combines cutting-edge technology with privacy-first design to protect whistleblowers and witnesses.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            <FeatureCard
              icon={<Shield className="w-10 h-10" />}
              title="Anonymous Reporting"
              description="Submit reports securely with automatic face blur, voice modulation, and metadata stripping."
              index={0}
            />
            <FeatureCard
              icon={<Brain className="w-10 h-10" />}
              title="AI Verification"
              description="Advanced AI systems verify evidence authenticity and detect tampering attempts."
              index={1}
            />
            <FeatureCard
              icon={<Lock className="w-10 h-10" />}
              title="Blockchain Security"
              description="Evidence is encrypted and hashed on blockchain for tamper-proof preservation."
              index={2}
            />
            <FeatureCard
              icon={<Scale className="w-10 h-10" />}
              title="Legal Aid"
              description="Connect with verified NGOs and lawyers who can help with your case."
              index={3}
            />
            <FeatureCard
              icon={<Bell className="w-10 h-10" />}
              title="Stealth Reporting"
              description="Emergency reporting features designed for high-risk situations."
              index={4}
            />
            <FeatureCard
              icon={<Users className="w-10 h-10" />}
              title="Community Impact"
              description="Join a network of citizens working together for transparency and justice."
              index={5}
            />
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section id="stats" className="py-24 px-4 sm:px-6 lg:px-8 relative">
        <div className="absolute inset-0">
          <div className="absolute inset-y-0 right-0 w-1/2 bg-gradient-to-l from-primary/10 to-transparent" />
          <div className="absolute inset-y-0 left-0 w-1/2 bg-gradient-to-r from-secondary/10 to-transparent blur-3xl" />
        </div>
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <div className="inline-block px-4 py-1 rounded-full bg-gradient-to-r from-secondary/20 to-secondary/5 border border-secondary/30 text-secondary mb-4">
              Our Impact
            </div>
            <h2 className="text-3xl sm:text-4xl font-bold mb-4 bg-gradient-to-r from-foreground to-foreground/80 bg-clip-text text-transparent">Making a Difference Together</h2>
            <p className="text-muted-foreground max-w-2xl mx-auto">
              Since our launch, CivicEye has helped thousands of people safely report injustice.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <StatCard
              number="10,000+"
              label="Reports Filed"
              icon={<div className="w-16 h-16 bg-gradient-to-br from-secondary/20 to-secondary/5 rounded-full flex items-center justify-center mb-4">
                <Shield className="w-8 h-8 text-secondary" />
              </div>}
            />
            <StatCard
              number="500+"
              label="NGO Partners"
              icon={<div className="w-16 h-16 bg-gradient-to-br from-secondary/20 to-secondary/5 rounded-full flex items-center justify-center mb-4">
                <Users className="w-8 h-8 text-secondary" />
              </div>}
            />
            <StatCard
              number="98%"
              label="Evidence Preservation Rate"
              icon={<div className="w-16 h-16 bg-gradient-to-br from-secondary/20 to-secondary/5 rounded-full flex items-center justify-center mb-4">
                <Lock className="w-8 h-8 text-secondary" />
              </div>}
            />
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section id="testimonials" className="py-24 px-4 sm:px-6 lg:px-8 relative">
        <div className="absolute inset-0">
          <div className="absolute inset-0 bg-gradient-to-b from-background via-primary/5 to-background -z-10" />
          <div className="absolute left-0 top-1/3 w-1/2 h-1/2 bg-gradient-to-tr from-primary/10 to-transparent blur-3xl" />
        </div>
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <div className="inline-block px-4 py-1 rounded-full bg-gradient-to-r from-primary/20 to-primary/5 border border-primary/30 text-primary mb-4">
              Testimonials
            </div>
            <h2 className="text-3xl sm:text-4xl font-bold mb-4 bg-gradient-to-r from-foreground to-foreground/80 bg-clip-text text-transparent">Success Stories</h2>
            <p className="text-muted-foreground max-w-2xl mx-auto">
              Our platform has helped people from all walks of life report injustice safely.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            <TestimonialCard
              quote="CivicEye gave me the confidence to report corruption in my workplace without fear of retaliation."
              author="Anonymous Whistleblower"
              role="Government Employee"
            />
            <TestimonialCard
              quote="The blockchain verification feature ensured my evidence couldn't be tampered with or denied. This was crucial for our case."
              author="J.M."
              role="Environmental Activist"
            />
            <TestimonialCard
              quote="I was connected with a pro-bono lawyer through CivicEye who helped turn my report into legal action."
              author="Anonymous"
              role="Community Member"
            />
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-24 px-4 sm:px-6 lg:px-8 relative">
        <div className="absolute inset-0 bg-gradient-to-r from-primary/30 to-secondary/30 opacity-20" />
        <div className="max-w-4xl mx-auto relative">
          <Card className="p-8 md:p-12 border-none bg-gradient-to-br from-card/90 to-card/50 backdrop-blur-lg shadow-xl">
            <div className="text-center">
              <div className="inline-block p-3 bg-gradient-to-br from-secondary/20 to-secondary/5 rounded-full mb-6">
                <Shield className="h-8 w-8 text-secondary" />
              </div>
              <h2 className="text-3xl font-bold mb-6 bg-gradient-to-r from-foreground via-secondary to-foreground bg-clip-text text-transparent">Ready to Make a Difference?</h2>
              <p className="text-lg mb-8 text-muted-foreground">
                Join thousands of citizens who are already using CivicEye to report and combat injustice.
              </p>
              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <Button size="lg" className="bg-gradient-to-r from-secondary to-primary text-white shadow-lg hover:opacity-90 border-0">
                  Get Started Now
                </Button>
                <Button size="lg" variant="outline" className="bg-white/5 border-white/20 hover:bg-white/10 backdrop-blur-sm">
                  Watch Demo <ExternalLink className="w-4 h-4 ml-2" />
                </Button>
              </div>
            </div>
          </Card>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-[#1e3b8a] border-t border-primary/10 py-12 px-4">

        <div className="max-w-7xl mx-auto">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
            <div>
              <div className="flex items-center gap-2 mb-4">
                <Shield className="text-secondary w-6 h-6" />
                <span className="font-bold text-lg bg-gradient-to-r from-foreground to-secondary bg-clip-text text-transparent">CivicEye</span>
              </div>
              <p className="text-sm text-muted-foreground mb-4">
                Empowering voices, protecting truth through secure anonymous reporting.
              </p>
              <div className="flex gap-4">
                <a href="#" className="text-muted-foreground hover:text-secondary transition-colors">
                  <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M8.29 20.251c7.547 0 11.675-6.253 11.675-11.675 0-.178 0-.355-.012-.53A8.348 8.348 0 0022 5.92a8.19 8.19 0 01-2.357.646 4.118 4.118 0 001.804-2.27 8.224 8.224 0 01-2.605.996 4.107 4.107 0 00-6.993 3.743 11.65 11.65 0 01-8.457-4.287 4.106 4.106 0 001.27 5.477A4.072 4.072 0 012.8 9.713v.052a4.105 4.105 0 003.292 4.022 4.095 4.095 0 01-1.853.07 4.108 4.108 0 003.834 2.85A8.233 8.233 0 012 18.407a11.616 11.616 0 006.29 1.84"></path>
                  </svg>
                </a>
                <a href="#" className="text-muted-foreground hover:text-secondary transition-colors">
                  <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path fillRule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clipRule="evenodd"></path>
                  </svg>
                </a>
              </div>
            </div>
            <div>
              <h3 className="font-semibold mb-4 bg-gradient-to-r from-foreground to-foreground/80 bg-clip-text text-transparent">Product</h3>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li><a href="#" className="hover:text-secondary transition-colors">Features</a></li>
                <li><a href="#" className="hover:text-secondary transition-colors">How it works</a></li>
                <li><a href="#" className="hover:text-secondary transition-colors">Pricing</a></li>
                <li><a href="#" className="hover:text-secondary transition-colors">Case studies</a></li>
              </ul>
            </div>
            <div>
              <h3 className="font-semibold mb-4 bg-gradient-to-r from-foreground to-foreground/80 bg-clip-text text-transparent">Resources</h3>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li><a href="#" className="hover:text-secondary transition-colors">Documentation</a></li>
                <li><a href="#" className="hover:text-secondary transition-colors">Blog</a></li>
                <li><a href="#" className="hover:text-secondary transition-colors">Partners</a></li>
                <li><a href="#" className="hover:text-secondary transition-colors">Support</a></li>
              </ul>
            </div>
            <div>
              <h3 className="font-semibold mb-4 bg-gradient-to-r from-foreground to-foreground/80 bg-clip-text text-transparent">Company</h3>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li><a href="#" className="hover:text-secondary transition-colors">About</a></li>
                <li><a href="#" className="hover:text-secondary transition-colors">Team</a></li>
                <li><a href="#" className="hover:text-secondary transition-colors">Careers</a></li>
                <li><a href="#" className="hover:text-secondary transition-colors">Contact</a></li>
              </ul>
            </div>
          </div>
          <div className="border-t border-primary/10 mt-12 pt-8 text-sm text-muted-foreground flex flex-col md:flex-row justify-between items-center">
            <p>© 2025 CivicEye. All rights reserved.</p>
            <div className="flex gap-8 mt-4 md:mt-0">
              <a href="#" className="hover:text-secondary transition-colors">Privacy Policy</a>
              <a href="#" className="hover:text-secondary transition-colors">Terms of Service</a>
              <a href="#" className="hover:text-secondary transition-colors">Cookie Policy</a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}

function FeatureCard({ icon, title, description, index }: { icon: React.ReactNode; title: string; description: string; index: number }) {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => {
      setIsVisible(true);
    }, 100 + index * 100);

    return () => clearTimeout(timer);
  }, [index]);

  return (
    <Card
      className={`p-6 flex flex-col items-center text-center bg-gradient-to-br from-primary/20 to-background backdrop-blur-sm border-primary/10 hover:border-secondary/30 transition-all hover:translate-y-[-5px] duration-300 hover:shadow-lg relative overflow-hidden ${isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'}`}
      style={{ transitionDelay: `${index * 50}ms` }}
    >
      <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-primary/0 via-secondary to-primary/0 opacity-50" />
      <div className="mb-6 text-secondary bg-gradient-to-br from-secondary/20 to-secondary/5 p-3 rounded-full">{icon}</div>
      <h3 className="text-xl font-semibold mb-3 bg-gradient-to-r from-foreground to-foreground/90 bg-clip-text text-transparent">{title}</h3>
      <p className="text-muted-foreground">{description}</p>
    </Card>
  );
}

function StatCard({ number, label, icon }: { number: string; label: string; icon: React.ReactNode }) {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          setIsVisible(true);
        }
      });
    }, { threshold: 0.1 });

    const currentElement = document.getElementById(`stat-${label.replace(/\s+/g, '-').toLowerCase()}`);
    if (currentElement) {
      observer.observe(currentElement);
    }

    return () => {
      if (currentElement) {
        observer.unobserve(currentElement);
      }
    };
  }, [label]);

  return (
    <Card
      id={`stat-${label.replace(/\s+/g, '-').toLowerCase()}`}
      className="p-8 bg-gradient-to-br from-card/80 to-card/40 backdrop-blur-sm border-primary/10 text-center hover:border-secondary/20 transition-all duration-300"
    >
      <div className='flex flex-col items-center'>
        {icon}
        <div className={`text-4xl text-foreground font-bold mb-2 transition-all duration-1000 bg-gradient-to-r from-secondary to-primary-light bg-clip-text ${isVisible ? 'opacity-100' : 'opacity-0 transform -translate-y-4'}`}>
          {number}
        </div>
        <div className="text-muted-foreground">{label}</div>
      </div>
    </Card>
  );
}

function TestimonialCard({ quote, author, role }: { quote: string; author: string; role: string }) {
  return (
    <Card className="p-6 bg-gradient-to-br from-card/80 to-card/40 backdrop-blur-sm border-primary/10 hover:border-secondary/20 transition-all duration-300">
      <div className="mb-4 text-secondary">
        <svg className="h-8 w-8" fill="currentColor" viewBox="0 0 24 24">
          <path d="M14.017 18L14.017 10.609C14.017 4.905 17.748 1.039 23 0L23.995 2.151C21.563 3.068 20 5.789 20 8H24V18H14.017ZM0 18V10.609C0 4.905 3.748 1.039 9 0L9.996 2.151C7.563 3.068 6 5.789 6 8H9.983L9.983 18L0 18Z" />
        </svg>
      </div>
      <blockquote className="text-lg font-medium mb-4">{quote}</blockquote>
      <div className="border-t border-primary/10 pt-4 mt-4">
        <p className="font-semibold bg-gradient-to-r from-foreground to-foreground/80 bg-clip-text text-transparent">{author}</p>
        <p className="text-sm text-muted-foreground">{role}</p>
      </div>
    </Card>
  );
}