'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Nav from '@/components/Nav';
import {
  STORAGE_KEYS, User, CalendarEvent, CalendarMode, MOCK_EVENTS
} from '@/lib/types';
import {
  format, startOfMonth, endOfMonth, startOfWeek, endOfWeek,
  addDays, addMonths, subMonths, isSameDay, isSameMonth, parseISO
} from 'date-fns';

/* ─── Event Modal ─── */
function EventModal({ event, onClose, onDelete }: { event: CalendarEvent; onClose: () => void; onDelete: (id: string) => void }) {
  const isPort = event.mode === 'port';
  const accentColor = isPort ? '#D48FAD' : '#E8A87C';
  
  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center p-4" onClick={onClose} style={{ background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(8px)' }}>
      <div
        className="relative w-full max-w-lg rounded-none p-10 lg:p-14 animate-fade-in-up"
        style={{ background: 'var(--bg)', border: '1px solid var(--border)' }}
        onClick={e => e.stopPropagation()}
      >
        {/* Subtle top accent line */}
        <div 
          className="absolute top-0 left-0 right-0 h-1"
          style={{ background: isPort ? 'linear-gradient(to right, #D48FAD, #B5638A)' : 'linear-gradient(to right, #E8A87C, #C4813A)' }}
        />

        <div className="flex items-center gap-3 mb-8">
          <div className="w-1.5 h-1.5 rounded-full" style={{ background: accentColor, boxShadow: `0 0 10px ${accentColor}` }} />
          <span className="text-xs uppercase tracking-widest font-light" style={{ color: 'var(--text-muted)' }}>
            {isPort ? 'The Port' : 'The Pursuit'}
          </span>
        </div>

        <h2
          className="mb-4 leading-tight"
          style={{
            fontFamily: 'var(--font-playfair)',
            fontSize: '2.5rem',
            fontWeight: 400,
            color: 'var(--text-primary)',
          }}
        >
          {event.emoji && <span className="mr-3">{event.emoji}</span>}
          {event.title}
        </h2>

        <div className="space-y-6 mt-10">
          <div className="flex items-start gap-4">
            <span className="text-[10px] uppercase tracking-widest w-20 pt-1 opacity-50">When</span>
            <p className="text-lg font-light" style={{ color: 'var(--text-secondary)' }}>
              {format(parseISO(event.date), 'EEEE, MMMM d, yyyy')}
              {(event.startTime || event.endTime) && (
                <span className="block mt-1 text-sm opacity-70">
                  {event.startTime && `${event.startTime}`}
                  {event.endTime && ` – ${event.endTime}`}
                </span>
              )}
            </p>
          </div>

          {event.location && (
            <div className="flex items-start gap-4">
              <span className="text-[10px] uppercase tracking-widest w-20 pt-1 opacity-50">Where</span>
              <p className="text-lg font-light" style={{ color: 'var(--text-secondary)' }}>{event.location}</p>
            </div>
          )}

          {event.description && (
            <div className="flex items-start gap-4">
              <span className="text-[10px] uppercase tracking-widest w-20 pt-1 opacity-50">Details</span>
              <p className="text-lg font-light leading-relaxed max-w-sm" style={{ color: 'var(--text-secondary)' }}>{event.description}</p>
            </div>
          )}

          <div className="flex items-start gap-4">
            <span className="text-[10px] uppercase tracking-widest w-20 pt-1 opacity-50">Added By</span>
            <p className="text-lg font-light" style={{ color: 'var(--text-secondary)' }}>{event.user}</p>
          </div>
        </div>

        <div className="flex items-center justify-between mt-16 pt-8" style={{ borderTop: '1px solid var(--border)' }}>
          <button
            onClick={() => { onDelete(event.id); onClose(); }}
            className="text-xs uppercase tracking-widest text-red-400 hover:text-red-300 transition-colors"
          >
            Delete Event
          </button>
          
          <button
            onClick={onClose}
            className="text-xs uppercase tracking-widest transition-colors"
            style={{ color: 'var(--text-muted)' }}
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}

/* ─── Add Event Modal ─── */
function AddEventModal({
  defaultDate, mode, activeUser, onAdd, onClose
}: {
  defaultDate: string;
  mode: CalendarMode;
  activeUser: User;
  onAdd: (e: CalendarEvent) => void;
  onClose: () => void;
}) {
  const [title, setTitle] = useState('');
  const [date, setDate] = useState(defaultDate);
  const [startTime, setStartTime] = useState('');
  const [endTime, setEndTime] = useState('');
  const [location, setLocation] = useState('');
  const [description, setDescription] = useState('');
  const [emoji, setEmoji] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;
    const ev: CalendarEvent = {
      id: crypto.randomUUID(), title, date, startTime: startTime || undefined,
      endTime: endTime || undefined, location: location || undefined,
      description: description || undefined, emoji: emoji || undefined,
      user: activeUser, mode,
    };
    onAdd(ev);
    onClose();
  };

  const isPort = mode === 'port';
  const accentColor = isPort ? '#D48FAD' : '#E8A87C';

  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center p-4" onClick={onClose} style={{ background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(8px)' }}>
      <div
        className="relative w-full max-w-lg rounded-none p-10 lg:p-14 animate-fade-in-up"
        style={{ background: 'var(--bg)', border: '1px solid var(--border)' }}
        onClick={e => e.stopPropagation()}
      >
        {/* Subtle top accent line */}
        <div 
          className="absolute top-0 left-0 right-0 h-1"
          style={{ background: isPort ? 'linear-gradient(to right, #D48FAD, #B5638A)' : 'linear-gradient(to right, #E8A87C, #C4813A)' }}
        />

        <div className="flex items-center gap-3 mb-8">
          <div className="w-1.5 h-1.5 rounded-full" style={{ background: accentColor, boxShadow: `0 0 10px ${accentColor}` }} />
          <span className="text-xs uppercase tracking-widest font-light" style={{ color: 'var(--text-muted)' }}>
            New Event · {isPort ? 'The Port' : 'The Pursuit'}
          </span>
        </div>

        <form onSubmit={handleSubmit} className="space-y-8">
          <div className="flex gap-4 items-end">
            <div className="w-16">
              <span className="text-[10px] uppercase tracking-widest opacity-50 mb-2 block">Emoji</span>
              <input type="text" value={emoji} onChange={e => setEmoji(e.target.value)} placeholder="🎉" maxLength={2} className="w-full text-center text-2xl border-b bg-transparent outline-none pb-2 transition-colors focus:border-[var(--text-primary)]" style={{ borderBottomColor: 'var(--border)' }} />
            </div>
            <div className="flex-1">
              <span className="text-[10px] uppercase tracking-widest opacity-50 mb-2 block">Title</span>
              <input type="text" value={title} onChange={e => setTitle(e.target.value)} placeholder="What's happening?" required className="w-full text-2xl font-light bg-transparent outline-none border-b pb-2 transition-colors focus:border-[var(--text-primary)]" style={{ fontFamily: 'var(--font-playfair)', borderBottomColor: 'var(--border)', color: 'var(--text-primary)' }} autoFocus />
            </div>
          </div>

          <div>
            <span className="text-[10px] uppercase tracking-widest opacity-50 mb-2 block">Date</span>
            <input type="date" value={date} onChange={e => setDate(e.target.value)} className="w-full text-lg font-light bg-transparent outline-none border-b pb-2 transition-colors focus:border-[var(--text-primary)]" style={{ borderBottomColor: 'var(--border)', color: 'var(--text-primary)' }} />
          </div>

          <div className="grid grid-cols-2 gap-8">
            <div>
              <span className="text-[10px] uppercase tracking-widest opacity-50 mb-2 block">Start Time</span>
              <input type="time" value={startTime} onChange={e => setStartTime(e.target.value)} className="w-full text-lg font-light bg-transparent outline-none border-b pb-2 transition-colors focus:border-[var(--text-primary)]" style={{ borderBottomColor: 'var(--border)', color: 'var(--text-primary)' }} />
            </div>
            <div>
              <span className="text-[10px] uppercase tracking-widest opacity-50 mb-2 block">End Time</span>
              <input type="time" value={endTime} onChange={e => setEndTime(e.target.value)} className="w-full text-lg font-light bg-transparent outline-none border-b pb-2 transition-colors focus:border-[var(--text-primary)]" style={{ borderBottomColor: 'var(--border)', color: 'var(--text-primary)' }} />
            </div>
          </div>

          <div>
            <span className="text-[10px] uppercase tracking-widest opacity-50 mb-2 block">Location</span>
            <input type="text" value={location} onChange={e => setLocation(e.target.value)} placeholder="Where is it?" className="w-full text-lg font-light bg-transparent outline-none border-b pb-2 transition-colors focus:border-[var(--text-primary)]" style={{ borderBottomColor: 'var(--border)', color: 'var(--text-primary)' }} />
          </div>

          <div>
            <span className="text-[10px] uppercase tracking-widest opacity-50 mb-2 block">Details</span>
            <textarea value={description} onChange={e => setDescription(e.target.value)} placeholder="Any extra notes..." rows={2} className="w-full text-lg font-light bg-transparent outline-none border-b pb-2 transition-colors focus:border-[var(--text-primary)] resize-none" style={{ borderBottomColor: 'var(--border)', color: 'var(--text-primary)' }} />
          </div>

          <div className="flex items-center justify-between pt-6">
            <button type="button" onClick={onClose} className="text-xs uppercase tracking-widest transition-colors" style={{ color: 'var(--text-muted)' }}>
              Cancel
            </button>
            <button type="submit" className="text-xs uppercase tracking-widest px-8 py-3 transition-colors border" style={{ color: accentColor, borderColor: accentColor }}>
              Add Event
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

/* ─── Calendar Page ─── */
export default function CalendarPage() {
  const router = useRouter();
  const [activeUser, setActiveUser] = useState<User>('User A');
  const [mode, setMode] = useState<CalendarMode>('pursuit');
  const [currentDate, setCurrentDate] = useState(new Date());
  const [events, setEvents] = useState<CalendarEvent[]>([]);
  const [selectedEvent, setSelectedEvent] = useState<CalendarEvent | null>(null);
  const [addDateStr, setAddDateStr] = useState<string | null>(null);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    const u = localStorage.getItem(STORAGE_KEYS.USER) as User;
    if (!u) { router.push('/login'); return; }
    setActiveUser(u);

    const theme = localStorage.getItem(STORAGE_KEYS.THEME) || 'dark';
    if (theme === 'dark') document.documentElement.classList.add('dark');
    else document.documentElement.classList.remove('dark');

    const saved = localStorage.getItem(STORAGE_KEYS.EVENTS);
    setEvents(saved ? JSON.parse(saved) : MOCK_EVENTS);
  }, [router]);

  useEffect(() => {
    if (!mounted) return;
    localStorage.setItem(STORAGE_KEYS.EVENTS, JSON.stringify(events));
  }, [events, mounted]);

  const addEvent = (ev: CalendarEvent) => setEvents(prev => [...prev, ev]);
  const deleteEvent = (id: string) => {
    setEvents(prev => prev.filter(e => e.id !== id));
  };

  // Build calendar grid
  const monthStart = startOfMonth(currentDate);
  const monthEnd   = endOfMonth(currentDate);
  const gridStart  = startOfWeek(monthStart);
  const gridEnd    = endOfWeek(monthEnd);

  const days: Date[] = [];
  let d = gridStart;
  while (d <= gridEnd) { days.push(d); d = addDays(d, 1); }

  // Filter events by mode
  const modeEvents = events.filter(e => e.mode === mode);
  const getEventsForDay = (day: Date) => modeEvents.filter(e => isSameDay(parseISO(e.date), day));

  if (!mounted) return null;

  const isPort = mode === 'port';
  const modeAccent = isPort ? '#D48FAD' : '#E8A87C';

  return (
    <div className="min-h-screen page-transition" style={{ background: 'var(--bg)' }}>
      <Nav activeUser={activeUser} setActiveUser={setActiveUser} />

      <main className="max-w-[1400px] mx-auto px-6 pt-32 pb-24">
        {/* Header & Mode Toggle */}
        <div className="flex flex-col md:flex-row md:items-end justify-between gap-8 mb-16">
          <div>
            <h1
              className="leading-[1.0] mb-6"
              style={{
                fontFamily: 'var(--font-playfair)',
                fontSize: 'clamp(3rem, 5vw, 4.5rem)',
                fontWeight: 400,
                color: 'var(--text-primary)',
                letterSpacing: '-0.02em',
              }}
            >
              Calendar
            </h1>
            
            {/* Elegant Month Navigation */}
            <div className="flex items-center gap-6">
              <button 
                onClick={() => setCurrentDate(subMonths(currentDate, 1))} 
                className="group flex items-center justify-center transition-colors hover:opacity-100 opacity-50"
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1" strokeLinecap="round" strokeLinejoin="round"><path d="M15 18l-6-6 6-6"/></svg>
              </button>
              
              <h2 className="text-xl tracking-widest uppercase font-light w-48 text-center" style={{ color: 'var(--text-primary)' }}>
                {format(currentDate, 'MMMM yyyy')}
              </h2>
              
              <button 
                onClick={() => setCurrentDate(addMonths(currentDate, 1))} 
                className="group flex items-center justify-center transition-colors hover:opacity-100 opacity-50"
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1" strokeLinecap="round" strokeLinejoin="round"><path d="M9 18l6-6-6-6"/></svg>
              </button>
            </div>
          </div>

          {/* Mode toggle — The Pursuit / The Port (Lines, not boxes) */}
          <div className="flex items-center gap-8 relative pb-2 border-b" style={{ borderColor: 'var(--border)' }}>
            {(['pursuit', 'port'] as CalendarMode[]).map(m => {
              const isActive = mode === m;
              return (
                <button
                  key={m}
                  onClick={() => setMode(m)}
                  className="pb-3 text-xs font-semibold tracking-widest uppercase transition-all duration-300 relative"
                  style={{
                    color: isActive ? 'var(--text-primary)' : 'var(--text-muted)',
                  }}
                >
                  {m === 'pursuit' ? 'The Pursuit' : 'The Port'}
                  {/* Active Underline */}
                  <div 
                    className="absolute -bottom-[1px] left-0 right-0 h-[2px] transition-all duration-300"
                    style={{
                      background: isActive ? (m === 'port' ? '#D48FAD' : '#E8A87C') : 'transparent',
                      transform: isActive ? 'scaleX(1)' : 'scaleX(0)',
                      boxShadow: isActive ? `0 0 10px ${m === 'port' ? '#D48FAD' : '#E8A87C'}` : 'none',
                    }}
                  />
                </button>
              );
            })}
          </div>
        </div>

        {/* Flat Grid Calendar */}
        <div className="w-full">
          {/* Weekday headers */}
          <div className="grid grid-cols-7 border-t border-b" style={{ borderColor: 'var(--border)' }}>
            {['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].map(day => (
              <div key={day} className="py-6 text-center text-[10px] font-semibold tracking-[0.2em] uppercase" style={{ color: 'var(--text-muted)' }}>
                {day}
              </div>
            ))}
          </div>

          {/* Day cells - Flat Lines */}
          <div className="grid grid-cols-7 border-l" style={{ borderColor: 'var(--border)' }}>
            {days.map((day, idx) => {
              const dayEvents = getEventsForDay(day);
              const isCurrentMonth = isSameMonth(day, currentDate);
              const isToday = isSameDay(day, new Date());
              const hasEvents = dayEvents.length > 0;

              return (
                <div
                  key={idx}
                  onClick={() => {
                    if (dayEvents.length > 0) {
                      // If only 1 event, open it. If multiple, maybe we should open a day view. 
                      // For simplicity, we just open the first one for now, or open the Add Event if clicked on empty space.
                      // Let's refine: clicking an event opens it, clicking the cell background adds one.
                      setAddDateStr(format(day, 'yyyy-MM-dd'));
                    } else {
                      setAddDateStr(format(day, 'yyyy-MM-dd'));
                    }
                  }}
                  className="min-h-[140px] p-4 cursor-pointer transition-colors duration-300 group relative flex flex-col"
                  style={{
                    borderRight: `1px solid var(--border)`,
                    borderBottom: `1px solid var(--border)`,
                    opacity: isCurrentMonth ? 1 : 0.3,
                    background: 'transparent',
                  }}
                  onMouseEnter={e => { e.currentTarget.style.background = 'rgba(255,255,255,0.015)'; }}
                  onMouseLeave={e => { e.currentTarget.style.background = 'transparent'; }}
                >
                  {isToday && (
                    <div 
                      className="absolute top-0 left-0 right-0 h-[2px]" 
                      style={{ background: modeAccent, boxShadow: `0 0 10px ${modeAccent}` }} 
                    />
                  )}
                  
                  <div className="flex items-start justify-between mb-3">
                    <span
                      className="text-2xl transition-all"
                      style={{
                        fontFamily: 'var(--font-playfair)',
                        color: isToday ? modeAccent : 'var(--text-secondary)',
                        fontWeight: isToday ? 500 : 400,
                      }}
                    >
                      {format(day, 'd')}
                    </span>
                    
                    {/* Hover Plus Icon */}
                    <div className="opacity-0 group-hover:opacity-100 transition-opacity mt-1">
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" style={{ color: 'var(--text-muted)' }}>
                        <path d="M7 2v10M2 7h10" stroke="currentColor" strokeWidth="1" strokeLinecap="round"/>
                      </svg>
                    </div>
                  </div>

                  {/* Elegant Event Chips */}
                  <div className="flex flex-col gap-2 flex-1">
                    {dayEvents.slice(0, 3).map(ev => (
                      <div
                        key={ev.id}
                        onClick={e => { e.stopPropagation(); setSelectedEvent(ev); }}
                        className="text-xs px-2 py-1.5 truncate font-light flex items-center gap-2 transition-all hover:bg-[rgba(255,255,255,0.03)] border-l-2"
                        style={{ 
                          color: 'var(--text-primary)',
                          borderColor: modeAccent,
                        }}
                      >
                        {ev.emoji && <span>{ev.emoji}</span>}
                        {ev.title}
                      </div>
                    ))}
                    {dayEvents.length > 3 && (
                      <p className="text-[10px] uppercase tracking-widest pl-2 mt-1" style={{ color: 'var(--text-muted)' }}>
                        +{dayEvents.length - 3} more
                      </p>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

      </main>

      {/* Modals */}
      {selectedEvent && (
        <EventModal 
          event={selectedEvent} 
          onClose={() => setSelectedEvent(null)} 
          onDelete={deleteEvent}
        />
      )}

      {addDateStr && (
        <AddEventModal
          defaultDate={addDateStr}
          mode={mode}
          activeUser={activeUser}
          onAdd={addEvent}
          onClose={() => setAddDateStr(null)}
        />
      )}
    </div>
  );
}
