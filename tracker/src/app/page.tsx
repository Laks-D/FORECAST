'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { STORAGE_KEYS } from '@/lib/types';

export default function LoadingPage() {
  const [progress, setProgress] = useState(0);
  const [done, setDone] = useState(false);
  const router = useRouter();

  useEffect(() => {
    // Smooth animation: ramp up quickly then ease at 100
    const duration = 2800;
    const startTime = performance.now();

    const animate = (now: number) => {
      const elapsed = now - startTime;
      const t = Math.min(elapsed / duration, 1);
      // Ease-out cubic
      const eased = 1 - Math.pow(1 - t, 3);
      const val = Math.floor(eased * 100);
      setProgress(val);

      if (t < 1) {
        requestAnimationFrame(animate);
      } else {
        setProgress(100);
        setTimeout(() => setDone(true), 600);
      }
    };

    requestAnimationFrame(animate);
  }, []);

  useEffect(() => {
    if (done) {
      const timeout = setTimeout(() => {
        // ALWAYS route to login first. We want to force authentication on load.
        localStorage.removeItem(STORAGE_KEYS.USER);
        router.push('/login');
      }, 500);
      return () => clearTimeout(timeout);
    }
  }, [done, router]);

  return (
    <div
      className="relative w-full h-screen overflow-hidden bg-[#0c1420]"
      style={{
        transition: done ? 'opacity 0.6s ease' : undefined,
        opacity: done ? 0 : 1,
      }}
    >
      {/* Background image */}
      <div
        className="absolute inset-0 bg-cover bg-center"
        style={{
          backgroundImage: 'url(/forecast_bg.jpg)',
          filter: 'brightness(0.75)',
        }}
      />

      {/* Subtle vignette overlay */}
      <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-black/30" />
      <div className="absolute inset-0 bg-gradient-to-r from-black/40 to-transparent" />

      {/* Brand name — top left */}
      <div className="absolute top-10 left-10 animate-fade-in" style={{ animationDelay: '0.2s', opacity: 0 }}>
        <span
          className="text-white/90 tracking-[0.18em] text-sm font-light uppercase"
          style={{ fontFamily: 'var(--font-dm-sans)' }}
        >
          Forecast
        </span>
      </div>

      {/* Large percentage — bottom left, exactly like Image 1 */}
      <div className="absolute bottom-16 left-10 leading-none">
        <span
          className="text-white/90 font-light"
          style={{
            fontFamily: 'var(--font-dm-sans)',
            fontSize: 'clamp(72px, 14vw, 160px)',
            letterSpacing: '-0.03em',
          }}
        >
          {progress}%
        </span>
      </div>

      {/* Thin progress bar at very bottom */}
      <div className="absolute bottom-0 left-0 right-0 h-[2px] bg-white/10">
        <div
          className="h-full bg-white/70 transition-all duration-100 ease-linear"
          style={{ width: `${progress}%` }}
        />
      </div>
    </div>
  );
}
