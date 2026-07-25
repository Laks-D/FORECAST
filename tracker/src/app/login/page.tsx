'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { STORAGE_KEYS, User } from '@/lib/types';

const PIN_A = '1423';
const PIN_B = '1021';

export default function LoginPage() {
  const router = useRouter();
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [pin, setPin] = useState('');
  const [error, setError] = useState('');
  const [step, setStep] = useState<'user' | 'pin'>('user');
  const [shaking, setShaking] = useState(false);

  const handleUserSelect = (user: User) => {
    setSelectedUser(user);
    setStep('pin');
    setPin('');
    setError('');
  };

  const handlePinDigit = (digit: string) => {
    if (pin.length >= 4) return;
    const newPin = pin + digit;
    setPin(newPin);

    if (newPin.length === 4) {
      setTimeout(() => {
        const expectedPin = selectedUser === 'User A' ? PIN_A : PIN_B;
        if (newPin === expectedPin) {
          localStorage.setItem(STORAGE_KEYS.USER, selectedUser!);
          const theme = localStorage.getItem(STORAGE_KEYS.THEME) || 'dark';
          if (theme === 'dark') document.documentElement.classList.add('dark');
          router.push('/home');
        } else {
          setShaking(true);
          setError('Incorrect PIN. Try again.');
          setPin('');
          setTimeout(() => setShaking(false), 600);
        }
      }, 100);
    }
  };

  const handleBack = () => {
    setStep('user');
    setSelectedUser(null);
    setPin('');
    setError('');
  };

  return (
    <div className="relative w-full h-screen overflow-hidden">
      {/* ── Full-bleed background ── */}
      <div
        className="absolute inset-0 bg-cover bg-center"
        style={{ backgroundImage: 'url(/forecast_bg.jpg)', filter: 'brightness(0.78)' }}
      />
      {/* Very faint gradient to make white text pop just a bit */}
      <div className="absolute inset-0 bg-gradient-to-t from-black/40 via-transparent to-transparent pointer-events-none" />

      {/* ── "FORECAST" — top left, noticeably larger ── */}
      <div className="absolute top-10 left-12 z-30">
        <span
          className="text-white tracking-[0.3em] uppercase font-light drop-shadow-md"
          style={{ fontFamily: 'var(--font-dm-sans)', fontSize: '1.2rem' }}
        >
          Forecast
        </span>
      </div>

      {/* ── Bottom-left copy — Redesigned for aesthetic elegance ── */}
      <div className="absolute bottom-16 left-12 z-30 max-w-lg">
        <h1
          className="text-white leading-[1.05] mb-5 drop-shadow-xl"
          style={{
            fontFamily: 'var(--font-playfair)',
            fontSize: 'clamp(2.5rem, 5vw, 4rem)',
            letterSpacing: '-0.01em',
          }}
        >
          <span className="italic font-light opacity-90 block mb-1">Your shared life,</span>
          <span className="font-medium">beautifully organized.</span>
        </h1>
        <p
          className="text-white/70 font-light tracking-[0.05em] uppercase"
          style={{ fontFamily: 'var(--font-dm-sans)', fontSize: '0.85rem' }}
        >
          Two people <span className="opacity-50 mx-2">|</span> One compass
        </p>
      </div>

      {/* ── Massive Hollow Login Card (Right Half) ── */}
      {/* Takes up 50% width on desktop, absolutely no background fill or blur */}
      <div className="absolute inset-y-0 right-0 w-full lg:w-[48vw] p-6 lg:p-8 flex items-center justify-center z-30">
        <div
          className="w-full h-full rounded-[2.5rem] flex flex-col items-center justify-center relative overflow-hidden transition-all duration-500"
          style={{
            background: 'transparent',
            backdropFilter: 'none',
            WebkitBackdropFilter: 'none',
            border: '1px solid rgba(255, 255, 255, 0.4)',
          }}
        >
          <div className="w-full max-w-md px-8 py-10 flex flex-col justify-center">
            {step === 'user' ? (
              <div className="w-full text-center fade-in">
                <h2
                  className="text-white mb-2 leading-tight drop-shadow-lg"
                  style={{
                    fontFamily: 'var(--font-playfair)',
                    fontSize: '2.5rem',
                    fontWeight: 500,
                  }}
                >
                  Who's logging in?
                </h2>
                <p
                  className="text-white/80 text-base mb-12 font-light drop-shadow-md"
                  style={{ fontFamily: 'var(--font-dm-sans)' }}
                >
                  Select your profile to continue.
                </p>

                <div className="space-y-4">
                  {(['User A', 'User B'] as User[]).map(user => {
                    const isA = user === 'User A';
                    return (
                      <button
                        key={user}
                        onClick={() => handleUserSelect(user)}
                        className="group w-full flex items-center gap-6 p-5 rounded-[1.5rem] transition-all duration-300"
                        style={{
                          background: 'transparent',
                          border: '1px solid rgba(255,255,255,0.3)',
                        }}
                        onMouseEnter={e => {
                          (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.08)';
                          (e.currentTarget as HTMLElement).style.borderColor = 'rgba(255,255,255,0.6)';
                          (e.currentTarget as HTMLElement).style.transform = 'translateY(-2px)';
                        }}
                        onMouseLeave={e => {
                          (e.currentTarget as HTMLElement).style.background = 'transparent';
                          (e.currentTarget as HTMLElement).style.borderColor = 'rgba(255,255,255,0.3)';
                          (e.currentTarget as HTMLElement).style.transform = 'translateY(0)';
                        }}
                      >
                        <div
                          className="w-16 h-16 rounded-full flex items-center justify-center text-white font-semibold shrink-0 transition-transform duration-300 group-hover:scale-105"
                          style={{
                            background: isA
                              ? 'linear-gradient(135deg, #E8A87C, #C4813A)'
                              : 'linear-gradient(135deg, #D48FAD, #B5638A)',
                            fontFamily: 'var(--font-playfair)',
                            fontSize: '1.4rem',
                            boxShadow: '0 4px 20px rgba(0,0,0,0.3)',
                          }}
                        >
                          {isA ? 'A' : 'B'}
                        </div>
                        <div className="text-left flex-1">
                          <p className="text-white font-medium text-lg mb-1 drop-shadow-md">
                            {user}
                          </p>
                          <p className="text-white/60 text-sm font-light">Tap to continue</p>
                        </div>
                        <svg
                          className="text-white/50 group-hover:text-white group-hover:translate-x-1.5 transition-all duration-300"
                          width="24" height="24" viewBox="0 0 24 24" fill="none"
                        >
                          <path d="M9 5l7 7-7 7" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                        </svg>
                      </button>
                    );
                  })}
                </div>


              </div>
            ) : (
              <div className="w-full max-w-sm mx-auto fade-in">
                <button
                  onClick={handleBack}
                  className="flex items-center gap-2 text-white/80 hover:text-white text-base mb-10 transition-colors group"
                >
                  <svg
                    className="group-hover:-translate-x-1 transition-transform"
                    width="18" height="18" viewBox="0 0 24 24" fill="none"
                  >
                    <path d="M15 19l-7-7 7-7" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                  Back
                </button>

                <div className="flex items-center justify-center gap-6 mb-12">
                  <div
                    className="w-20 h-20 rounded-full flex items-center justify-center text-white font-semibold shrink-0"
                    style={{
                      background: selectedUser === 'User A'
                        ? 'linear-gradient(135deg, #E8A87C, #C4813A)'
                        : 'linear-gradient(135deg, #D48FAD, #B5638A)',
                      fontFamily: 'var(--font-playfair)',
                      fontSize: '1.8rem',
                      boxShadow: '0 8px 32px rgba(0,0,0,0.4)',
                    }}
                  >
                    {selectedUser === 'User A' ? 'A' : 'B'}
                  </div>
                  <div className="text-left">
                    <p className="text-white font-medium text-2xl mb-1 drop-shadow-md">{selectedUser}</p>
                    <p className="text-white/80 text-base font-light">Enter 4-digit PIN</p>
                  </div>
                </div>

                {/* PIN dots */}
                <div
                  className="flex gap-6 justify-center mb-4"
                  style={{ animation: shaking ? 'shake 0.5s ease' : undefined }}
                >
                  {[0, 1, 2, 3].map(i => (
                    <div
                      key={i}
                      className="rounded-full transition-all duration-300"
                      style={{
                        width: pin.length > i ? '18px' : '16px',
                        height: pin.length > i ? '18px' : '16px',
                        background: pin.length > i
                          ? (selectedUser === 'User A' ? '#E8A87C' : '#D48FAD')
                          : 'transparent',
                        border: pin.length > i ? 'none' : '1px solid rgba(255,255,255,0.6)',
                        boxShadow: pin.length > i ? '0 0 12px rgba(255,255,255,0.2)' : 'none',
                      }}
                    />
                  ))}
                </div>

                <div className="h-8 flex items-center justify-center mb-8">
                  {error && (
                    <p className="text-red-400/90 text-sm font-medium">{error}</p>
                  )}
                </div>

                {/* Numpad */}
                <div className="grid grid-cols-3 gap-3">
                  {['1','2','3','4','5','6','7','8','9','','0','⌫'].map((d, i) => (
                    <button
                      key={i}
                      onClick={() => {
                        if (d === '⌫') setPin(p => p.slice(0, -1));
                        else if (d !== '') handlePinDigit(d);
                      }}
                      disabled={d === ''}
                      className="h-20 rounded-[1.2rem] text-white text-3xl font-light transition-all duration-200 active:scale-95 disabled:opacity-0 flex items-center justify-center"
                      style={{
                        background: 'transparent',
                        border: d !== '' ? '1px solid rgba(255,255,255,0.3)' : 'none',
                      }}
                      onMouseEnter={e => {
                        if (d) {
                          (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.1)';
                          (e.currentTarget as HTMLElement).style.borderColor = 'rgba(255,255,255,0.5)';
                        }
                      }}
                      onMouseLeave={e => {
                        if (d) {
                          (e.currentTarget as HTMLElement).style.background = 'transparent';
                          (e.currentTarget as HTMLElement).style.borderColor = 'rgba(255,255,255,0.3)';
                        }
                      }}
                    >
                      {d}
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      <style jsx>{`
        @keyframes shake {
          0%, 100% { transform: translateX(0); }
          20%       { transform: translateX(-10px); }
          40%       { transform: translateX(10px); }
          60%       { transform: translateX(-8px); }
          80%       { transform: translateX(8px); }
        }
        .fade-in {
          animation: fadeIn 0.4s ease-out forwards;
        }
        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(10px); }
          to { opacity: 1; transform: translateY(0); }
        }
      `}</style>
    </div>
  );
}
