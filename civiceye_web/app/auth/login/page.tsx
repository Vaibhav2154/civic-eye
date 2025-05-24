'use client'

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabaseClient'
import { useRouter } from 'next/navigation'
import Image from 'next/image'

export default function AuthForm() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [isLogin, setIsLogin] = useState(true)
  const [username, setUsername] = useState('')
  const [phone, setPhone] = useState('')
  const [errors, setErrors] = useState<string[]>([])
  const [carouselIndex, setCarouselIndex] = useState(0)
  const router = useRouter()

  const taglines = [
    'Be the Change',
    'Real-time Civic Reporting',
    'Anonymous & Secure',
    'Truth in Motion',
  ]

  useEffect(() => {
    const interval = setInterval(() => {
      setCarouselIndex((prev) => (prev + 1) % taglines.length)
    }, 3000)
    return () => clearInterval(interval)
  }, [])

  const validateFields = () => {
    const newErrors: string[] = []

    if (!email.trim()) newErrors.push('Email is required.')
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) newErrors.push('Invalid email format.')

    if (!password.trim()) newErrors.push('Password is required.')
    else if (password.length < 6) newErrors.push('Password must be at least 6 characters.')

    if (!isLogin) {
      if (!username.trim()) newErrors.push('Username is required.')
      if (!phone.trim()) newErrors.push('Phone number is required.')
      if (!confirmPassword.trim()) newErrors.push('Confirm password is required.')
      else if (password !== confirmPassword) newErrors.push('Passwords do not match.')
    }

    setErrors(newErrors)
    return newErrors.length === 0
  }

  const handleAuth = async () => {
    if (!validateFields()) return

    if (isLogin) {
      const { error } = await supabase.auth.signInWithPassword({ email, password })
      if (error) {
        setErrors([`Login failed: ${error.message}`])
      } else {
        const {
          data: { user },
        } = await supabase.auth.getUser()

        if (user) {
          const { data: userData, error: userError } = await supabase
            .from('users')
            .select('role')
            .eq('id', user.id)
            .single()

          if (userError || !userData || userData.role !== 'admin') {
            await supabase.auth.signOut()
            setErrors(['Access Denied: Only authorized admins are allowed to login'])
            return
          }

          await supabase
            .from('users')
            .update({ last_active_at: new Date().toISOString() })
            .eq('id', user.id)
        }

        router.push('/dashboard')
      }
    } else {
      const { data, error } = await supabase.auth.signUp({ email, password })
      const userId = data?.user?.id
      if (error) {
        setErrors([`Signup failed: ${error.message}`])
      } else {
        await supabase.from('users').insert([
          {
            id: userId,
            email,
            full_name: username,
            phone,
            role: 'admin',
          },
        ])
        alert('Signup successful! Please check your email and then log in.')
        setIsLogin(true)
      }
    }
  }

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-black text-white px-4 py-10">
<div className="flex items-center mb-2">
  <Image
    src="/logo3.png"
    alt="CivicEye Logo"
    width={50}
    height={50}
    className="mr-2"
  />
  <h1 className="text-4xl font-extrabold tracking-wide text-blue-300 drop-shadow-lg m-0 p-0 leading-none">
    CivicEye
  </h1>
</div>


      <p className="text-md mb-6 text-gray-400 italic">{taglines[carouselIndex]}</p>

      <div className="w-full max-w-md p-8 rounded-3xl backdrop-blur-md bg-[#ffffff0d] border border-[#ffffff1a] shadow-[0_8px_32px_0_rgba(31,38,135,0.37)]">
        <h2 className="text-2xl font-bold text-center mb-6 text-cyan-300 tracking-wide drop-shadow-lg">
          {isLogin ? 'Log In' : 'Sign Up'}
        </h2>

        {errors.length > 0 && (
          <div className="mb-5 p-4 text-sm bg-red-900 bg-opacity-30 border border-red-500 rounded-xl">
            <ul className="list-disc pl-5 space-y-1 text-red-300">
              {errors.map((err, idx) => (
                <li key={idx}>{err}</li>
              ))}
            </ul>
          </div>
        )}

        {!isLogin && (
          <input
            className="w-full p-3 mb-4 bg-zinc-700 text-white rounded outline-none"
            type="text"
            placeholder="Username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
          />
        )}

        <input
          className="w-full p-3 mb-4 bg-zinc-700 text-white rounded outline-none"
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />

        {!isLogin && (
          <input
            className="w-full p-3 mb-4 bg-zinc-700 text-white rounded outline-none"
            type="text"
            placeholder="Phone number"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
          />
        )}

        <input
          className="w-full p-3 mb-4 bg-zinc-700 text-white rounded outline-none"
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />

        {!isLogin && (
          <input
            className="w-full p-3 mb-6 bg-zinc-700 text-white rounded outline-none"
            type="password"
            placeholder="Confirm Password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
          />
        )}

        <button
          onClick={handleAuth}
          className="w-full py-3 bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 rounded-xl font-semibold text-white shadow-lg transition-all duration-300"
        >
          {isLogin ? 'Log In' : 'Sign Up'}
        </button>

        <p className="text-sm text-center text-white mt-4">
          {isLogin ? "Don't have an account?" : 'Already have an account?'}{' '}
          <button
            className="text-cyan-400 ml-1 hover:underline hover:cursor-pointer"
            onClick={() => {
              setIsLogin(!isLogin)
              setErrors([])
            }}
          >
            {isLogin ? 'Sign Up' : 'Log In'}
          </button>
        </p>
      </div>
    </div>
  )
}
