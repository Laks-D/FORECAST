'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { STORAGE_KEYS, User } from '@/lib/types';

const NAV_ITEMS = [
  { label: 'Home',     href: '/home' },
  { label: 'Calendar', href: '/calendar' },
  { label: 'Tasks',    href: '/tasks' },
  { label: 'Notes',    href: '/notes' },
];

interface NavProps {
  activeUser: User;
  setActiveUser: (u: User) => void;
}

export default function Nav({ activeUser, setActiveUser }: NavProps) {
  const pathname = usePathname();
  const router   = useRouter();
  const [dark, setDark] = useState(true);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem(STORAGE_KEYS.THEME);
    const isDark = stored !== 'light';
    setDark(isDark);
    if (isDark) document.documentElement.classList.add('dark');
    else document.documentElement.classList.remove('dark');
  }, []);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const toggleTheme = () => {
    const next = !dark;
    setDark(next);
    localStorage.setItem(STORAGE_KEYS.THEME, next ? 'dark' : 'light');
    if (next) document.documentElement.classList.add('dark');
    else document.documentElement.classList.remove('dark');
  };

  const handleUserSwitch = (u: User) => {
    setActiveUser(u);
    localStorage.setItem(STORAGE_KEYS.USER, u);
  };

  const handleLogout = () => {
    localStorage.removeItem(STORAGE_KEYS.USER);
    router.push('/login');
  };

  return (
    <header
      className="fixed top-0 left-0 right-0 z-50 transition-all duration-300"
      style={{
        background: scrolled
          ? 'rgba(11,14,17,0.85)'
          : 'transparent',
        backdropFilter: scrolled ? 'blur(20px)' : 'none',
        WebkitBackdropFilter: scrolled ? 'blur(20px)' : 'none',
        borderBottom: scrolled ? '1px solid rgba(255,255,255,0.06)' : '1px solid transparent',
      }}
    >
      <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
        {/* Brand */}
        <Link href="/home">
          <span
            className="text-[var(--text-primary)] tracking-[0.2em] text-sm font-light uppercase opacity-80 hover:opacity-100 transition-opacity"
            style={{ fontFamily: 'var(--font-dm-sans)' }}
          >
            Forecast
          </span>
        </Link>

        {/* Nav links */}
        <nav className="hidden md:flex items-center gap-1">
          {NAV_ITEMS.map(({ label, href }) => {
            const active = pathname === href;
            return (
              <Link
                key={href}
                href={href}
                className="px-4 py-2 rounded-full text-sm transition-all duration-200"
                style={{
                  color: active ? 'var(--text-primary)' : 'var(--text-muted)',
                  background: active ? 'rgba(255,255,255,0.08)' : 'transparent',
                  fontWeight: active ? 500 : 400,
                }}
              >
                {label}
              </Link>
            );
          })}
        </nav>

        {/* Right controls */}
        <div className="flex items-center gap-3">
          {/* User toggle */}
          <div
            className="flex items-center rounded-full p-1 gap-1"
            style={{ background: 'rgba(255,255,255,0.06)', border: '1px solid var(--border)' }}
          >
            {(['User A', 'User B'] as User[]).map((u) => (
              <button
                key={u}
                onClick={() => handleUserSwitch(u)}
                className="w-8 h-8 rounded-full text-xs font-medium transition-all duration-300"
                style={{
                  background: activeUser === u
                    ? (u === 'User A' ? 'linear-gradient(135deg, #E8A87C, #C4813A)' : 'linear-gradient(135deg, #D48FAD, #B5638A)')
                    : 'transparent',
                  color: activeUser === u ? 'white' : 'var(--text-muted)',
                }}
              >
                {u === 'User A' ? 'A' : 'B'}
              </button>
            ))}
          </div>

          {/* Theme toggle */}
          <button
            onClick={toggleTheme}
            className="w-9 h-9 rounded-full flex items-center justify-center transition-all duration-300 hover:bg-white/8"
            style={{ color: 'var(--text-muted)', border: '1px solid var(--border)' }}
            title={dark ? 'Switch to light mode' : 'Switch to dark mode'}
          >
            {dark ? (
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>
              </svg>
            ) : (
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                <path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/>
              </svg>
            )}
          </button>

          {/* Logout */}
          <button
            onClick={handleLogout}
            className="hidden md:flex text-xs text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-colors font-light"
          >
            Sign out
          </button>
        </div>
      </div>
    </header>
  );
}
