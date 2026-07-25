'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Nav from '@/components/Nav';
import { STORAGE_KEYS, User, Task, Reminder, CalendarEvent, MOCK_TASKS, MOCK_EVENTS, MOCK_REMINDERS } from '@/lib/types';
import { format, isToday, isTomorrow, parseISO } from 'date-fns';

const GREETINGS = {
  morning:   'Good morning',
  afternoon: 'Good afternoon',
  evening:   'Good evening',
  night:     'Good night',
};

function getGreeting() {
  const h = new Date().getHours();
  if (h < 12) return GREETINGS.morning;
  if (h < 17) return GREETINGS.afternoon;
  if (h < 21) return GREETINGS.evening;
  return GREETINGS.night;
}

function formatReminderTime(dt: string) {
  const d = parseISO(dt);
  if (isToday(d)) return `Today, ${format(d, 'h:mm a')}`;
  if (isTomorrow(d)) return `Tomorrow, ${format(d, 'h:mm a')}`;
  return format(d, 'MMM d, h:mm a');
}

export default function HomePage() {
  const router = useRouter();
  const [activeUser, setActiveUser] = useState<User>('User A');
  const [tasks, setTasks] = useState<Task[]>([]);
  const [reminders, setReminders] = useState<Reminder[]>([]);
  const [events, setEvents] = useState<CalendarEvent[]>([]);
  const [mounted, setMounted] = useState(false);
  const [newTask, setNewTask] = useState('');
  const [newReminder, setNewReminder] = useState('');

  useEffect(() => {
    setMounted(true);
    const u = localStorage.getItem(STORAGE_KEYS.USER) as User;
    if (!u) { router.push('/login'); return; }
    setActiveUser(u);

    // Init theme
    const theme = localStorage.getItem(STORAGE_KEYS.THEME) || 'dark';
    if (theme === 'dark') document.documentElement.classList.add('dark');
    else document.documentElement.classList.remove('dark');

    // Load data
    const savedTasks = localStorage.getItem(STORAGE_KEYS.TASKS);
    setTasks(savedTasks ? JSON.parse(savedTasks) : MOCK_TASKS);

    const savedReminders = localStorage.getItem(STORAGE_KEYS.REMINDERS);
    setReminders(savedReminders ? JSON.parse(savedReminders) : MOCK_REMINDERS);

    const savedEvents = localStorage.getItem(STORAGE_KEYS.EVENTS);
    setEvents(savedEvents ? JSON.parse(savedEvents) : MOCK_EVENTS);
  }, [router]);

  useEffect(() => {
    if (!mounted) return;
    localStorage.setItem(STORAGE_KEYS.TASKS, JSON.stringify(tasks));
  }, [tasks, mounted]);

  useEffect(() => {
    if (!mounted) return;
    localStorage.setItem(STORAGE_KEYS.REMINDERS, JSON.stringify(reminders));
  }, [reminders, mounted]);

  const toggleTask = (id: string) => {
    setTasks(prev => prev.map(t => t.id === id ? { ...t, status: t.status === 'Done' ? 'Pending' : 'Done' } : t));
  };

  const addTask = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTask.trim()) return;
    const t: Task = {
      id: crypto.randomUUID(), title: newTask, priority: 'Medium', status: 'Pending',
      assignedTo: activeUser, subtasks: [], createdAt: new Date().toISOString()
    };
    setTasks(prev => [t, ...prev]);
    setNewTask('');
  };

  const toggleReminder = (id: string) => {
    setReminders(prev => prev.map(r => r.id === id ? { ...r, done: !r.done } : r));
  };

  const todayTasks = tasks.filter(t => t.assignedTo === activeUser && t.status !== 'Done');
  const completedToday = tasks.filter(t => t.assignedTo === activeUser && t.status === 'Done');
  const myReminders = reminders.filter(r => r.user === activeUser || !r.done).slice(0, 4);
  const upcomingEvents = events
    .filter(e => new Date(e.date) >= new Date(new Date().setHours(0,0,0,0)))
    .sort((a, b) => a.date.localeCompare(b.date))
    .slice(0, 3);

  const today = new Date();
  const todayStr = format(today, 'EEEE, MMMM d');

  if (!mounted) return null;

  return (
    <div className="min-h-screen" style={{ background: 'var(--bg)' }}>
      <Nav activeUser={activeUser} setActiveUser={setActiveUser} />

      <main className="max-w-6xl mx-auto px-6 pt-28 pb-24">
        {/* ─── Hero Greeting ─── */}
        <div className="mb-16">
          <p className="text-sm font-light tracking-widest uppercase mb-3" style={{ color: 'var(--text-muted)' }}>
            {todayStr}
          </p>
          <h1
            className="leading-[1.05] mb-4"
            style={{
              fontFamily: 'var(--font-playfair)',
              fontSize: 'clamp(2.8rem, 6vw, 5rem)',
              fontWeight: 500,
              color: 'var(--text-primary)',
              letterSpacing: '-0.02em',
            }}
          >
            {getGreeting()},<br/>
            <span style={{ color: activeUser === 'User A' ? 'var(--accent)' : 'var(--port)' }}>
              {activeUser}.
            </span>
          </h1>
          <p className="font-light" style={{ color: 'var(--text-secondary)', fontSize: '1.1rem' }}>
            You have <strong style={{ color: 'var(--text-primary)', fontWeight: 500 }}>{todayTasks.length} tasks</strong> open
            {upcomingEvents.length > 0 && <> and <strong style={{ color: 'var(--text-primary)', fontWeight: 500 }}>{upcomingEvents.length} events</strong> coming up.</>}
          </p>
        </div>

        {/* ─── Main grid ─── */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Tasks — spans 2 cols */}
          <div className="lg:col-span-2 space-y-6">
            {/* Today's tasks card */}
            <div
              className="rounded-2xl p-8 transition-all"
              style={{ background: 'var(--surface)', border: '1px solid var(--border)' }}
            >
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-lg font-medium" style={{ color: 'var(--text-primary)', fontFamily: 'var(--font-playfair)' }}>
                  Today&apos;s Queue
                </h2>
                <span
                  className="text-xs px-3 py-1 rounded-full font-medium"
                  style={{
                    background: 'var(--accent-light)',
                    color: 'var(--accent)',
                  }}
                >
                  {todayTasks.length} open
                </span>
              </div>

              {/* Quick add */}
              <form onSubmit={addTask} className="mb-6">
                <div
                  className="flex items-center gap-3 rounded-xl px-4 py-3 transition-all"
                  style={{ background: 'var(--surface-2)', border: '1px solid var(--border)' }}
                >
                  <svg width="16" height="16" viewBox="0 0 16 16" fill="none" style={{ color: 'var(--text-muted)' }}>
                    <circle cx="8" cy="8" r="7" stroke="currentColor" strokeWidth="1.5"/>
                    <path d="M8 5v6M5 8h6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
                  </svg>
                  <input
                    type="text"
                    value={newTask}
                    onChange={e => setNewTask(e.target.value)}
                    placeholder="Add a task for today..."
                    className="flex-1 bg-transparent text-sm font-light border-none outline-none"
                    style={{ color: 'var(--text-primary)' }}
                  />
                  {newTask && (
                    <button type="submit" className="text-xs px-3 py-1.5 rounded-lg font-medium transition-colors" style={{ background: 'var(--accent)', color: 'white' }}>
                      Add
                    </button>
                  )}
                </div>
              </form>

              <div className="space-y-2">
                {todayTasks.length === 0 && (
                  <p className="text-sm py-4 text-center font-light" style={{ color: 'var(--text-muted)' }}>
                    All clear — nothing queued for today. ✨
                  </p>
                )}
                {todayTasks.map(task => (
                  <div key={task.id} className="flex items-start gap-3 group p-3 rounded-xl hover:bg-[var(--surface-2)] transition-colors duration-200 cursor-pointer" onClick={() => toggleTask(task.id)}>
                    <div
                      className="w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 mt-0.5 transition-all"
                      style={{
                        borderColor: task.assignedTo === 'User A' ? 'var(--accent)' : 'var(--port)',
                      }}
                    />
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium truncate" style={{ color: 'var(--text-primary)' }}>{task.title}</p>
                      <p className="text-xs mt-0.5" style={{ color: 'var(--text-muted)' }}>{task.priority} priority</p>
                    </div>
                  </div>
                ))}

                {completedToday.length > 0 && (
                  <div className="mt-4 pt-4" style={{ borderTop: '1px solid var(--border)' }}>
                    <p className="text-xs mb-3 font-medium" style={{ color: 'var(--text-muted)' }}>Completed</p>
                    {completedToday.map(task => (
                      <div key={task.id} className="flex items-center gap-3 p-3 opacity-50 cursor-pointer hover:opacity-70 transition-opacity" onClick={() => toggleTask(task.id)}>
                        <div className="w-5 h-5 rounded-full flex items-center justify-center shrink-0" style={{ background: 'var(--text-muted)' }}>
                          <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                            <path d="M2 5l2.5 2.5L8 3" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                          </svg>
                        </div>
                        <p className="text-sm line-through font-light" style={{ color: 'var(--text-muted)' }}>{task.title}</p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Upcoming events card */}
            <div
              className="rounded-2xl p-8"
              style={{ background: 'var(--surface)', border: '1px solid var(--border)' }}
            >
              <h2 className="text-lg font-medium mb-6" style={{ color: 'var(--text-primary)', fontFamily: 'var(--font-playfair)' }}>
                Coming Up
              </h2>
              <div className="space-y-4">
                {upcomingEvents.length === 0 && (
                  <p className="text-sm text-center py-4 font-light" style={{ color: 'var(--text-muted)' }}>No upcoming events.</p>
                )}
                {upcomingEvents.map(ev => {
                  const evDate = parseISO(ev.date);
                  const isPort = ev.mode === 'port';
                  return (
                    <div key={ev.id} className="flex items-center gap-4 p-4 rounded-xl" style={{ background: 'var(--surface-2)', border: '1px solid var(--border)' }}>
                      <div
                        className="w-10 h-10 rounded-xl flex items-center justify-center text-lg shrink-0"
                        style={{ background: isPort ? 'var(--port-light)' : 'var(--accent-light)' }}
                      >
                        {ev.emoji || (isPort ? '🌹' : '📋')}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium truncate" style={{ color: 'var(--text-primary)' }}>{ev.title}</p>
                        <p className="text-xs mt-0.5 font-light" style={{ color: 'var(--text-muted)' }}>
                          {isToday(evDate) ? 'Today' : isTomorrow(evDate) ? 'Tomorrow' : format(evDate, 'MMM d')}
                          {ev.startTime && ` · ${ev.startTime}`}
                          {ev.location && ` · ${ev.location}`}
                        </p>
                      </div>
                      <span
                        className="text-xs px-2.5 py-1 rounded-full font-medium shrink-0"
                        style={{
                          background: isPort ? 'var(--port-light)' : 'var(--accent-light)',
                          color: isPort ? 'var(--port)' : 'var(--accent)',
                        }}
                      >
                        {isPort ? 'The Port' : 'The Pursuit'}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Right column — Reminders + quote */}
          <div className="space-y-6">
            {/* Reminders */}
            <div
              className="rounded-2xl p-6"
              style={{ background: 'var(--surface)', border: '1px solid var(--border)' }}
            >
              <h2 className="text-lg font-medium mb-5" style={{ color: 'var(--text-primary)', fontFamily: 'var(--font-playfair)' }}>
                Reminders
              </h2>
              <div className="space-y-3">
                {myReminders.length === 0 && (
                  <p className="text-sm font-light text-center py-3" style={{ color: 'var(--text-muted)' }}>No reminders set.</p>
                )}
                {myReminders.map(r => (
                  <div key={r.id} className="flex items-start gap-3 cursor-pointer group" onClick={() => toggleReminder(r.id)}>
                    <div
                      className="w-5 h-5 rounded-md border flex items-center justify-center shrink-0 mt-0.5 transition-all"
                      style={{
                        borderColor: r.done ? 'var(--text-muted)' : 'var(--accent)',
                        background: r.done ? 'var(--text-muted)' : 'transparent',
                      }}
                    >
                      {r.done && (
                        <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                          <path d="M2 5l2.5 2.5L8 3" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                        </svg>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className={`text-sm font-medium ${r.done ? 'line-through opacity-40' : ''}`} style={{ color: 'var(--text-primary)' }}>{r.title}</p>
                      <p className="text-xs mt-0.5 font-light" style={{ color: 'var(--text-muted)' }}>{formatReminderTime(r.datetime)}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Daily thought / mood card */}
            <div
              className="rounded-2xl p-6 relative overflow-hidden"
              style={{
                background: 'linear-gradient(135deg, rgba(196,129,58,0.15), rgba(181,99,138,0.15))',
                border: '1px solid var(--border)',
              }}
            >
              <div
                className="absolute inset-0 opacity-30"
                style={{
                  background: 'url(/forecast_bg.jpg) center/cover',
                  filter: 'blur(2px) brightness(0.3)',
                }}
              />
              <div className="relative z-10">
                <p className="text-xs tracking-widest uppercase mb-4 font-medium" style={{ color: 'var(--text-muted)' }}>
                  Thought of the Day
                </p>
                <p
                  className="leading-relaxed"
                  style={{
                    fontFamily: 'var(--font-playfair)',
                    fontSize: '1.05rem',
                    fontWeight: 400,
                    color: 'var(--text-primary)',
                    fontStyle: 'italic',
                  }}
                >
                  &ldquo;The best thing to hold onto in life is each other.&rdquo;
                </p>
                <p className="text-xs mt-4 font-light" style={{ color: 'var(--text-muted)' }}>— Audrey Hepburn</p>
              </div>
            </div>

            {/* Quick stats */}
            <div className="grid grid-cols-2 gap-3">
              {[
                { label: 'Tasks Done', value: completedToday.length, accent: 'var(--accent)' },
                { label: 'Events Soon', value: upcomingEvents.length, accent: 'var(--port)' },
              ].map(stat => (
                <div
                  key={stat.label}
                  className="rounded-2xl p-5 text-center"
                  style={{ background: 'var(--surface)', border: '1px solid var(--border)' }}
                >
                  <p className="text-3xl font-light mb-1" style={{ color: stat.accent, fontFamily: 'var(--font-playfair)' }}>
                    {stat.value}
                  </p>
                  <p className="text-xs font-light" style={{ color: 'var(--text-muted)' }}>{stat.label}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
