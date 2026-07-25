'use client';
import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import Nav from '@/components/Nav';
import { STORAGE_KEYS, User, Task, Subtask, Priority, Status, MOCK_TASKS } from '@/lib/types';

/* ─── Priority config ─── */
const PRIORITIES: { value: Priority; label: string; color: string; bg: string }[] = [
  { value: 'Low',    label: 'Low',    color: '#6B7A8D', bg: 'rgba(107,122,141,0.12)' },
  { value: 'Medium', label: 'Medium', color: '#E8A87C', bg: 'rgba(232,168,124,0.12)' },
  { value: 'High',   label: 'High',   color: '#D48FAD', bg: 'rgba(212,143,173,0.12)' },
  { value: 'Urgent', label: 'Urgent', color: '#E05C5C', bg: 'rgba(224,92,92,0.12)'  },
];

const getPriority = (v: Priority) => PRIORITIES.find(p => p.value === v) ?? PRIORITIES[1];

/* ─── Status cycle: Pending → In Progress → Done ─── */
const nextStatus = (s: Status): Status => {
  if (s === 'Pending') return 'In Progress';
  if (s === 'In Progress') return 'Done';
  return 'Pending';
};

/* ─── Custom Priority Dropdown ─── */
function PriorityPicker({
  value,
  onChange,
}: {
  value: Priority;
  onChange: (p: Priority) => void;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const cfg = getPriority(value);

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  return (
    <div ref={ref} className="custom-dropdown shrink-0">
      <button
        type="button"
        onClick={() => setOpen(o => !o)}
        className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium transition-all duration-200 hover:opacity-80"
        style={{
          background: cfg.bg,
          color: cfg.color,
          border: `1px solid ${cfg.color}30`,
        }}
      >
        <span className="w-2 h-2 rounded-full shrink-0" style={{ background: cfg.color }} />
        {cfg.label}
        <svg
          width="12" height="12" viewBox="0 0 12 12" fill="none"
          style={{ marginLeft: 2, opacity: 0.6, transform: open ? 'rotate(180deg)' : 'none', transition: 'transform 0.2s' }}
        >
          <path d="M2 4l4 4 4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      </button>

      {open && (
        <div className="custom-dropdown-menu">
          {PRIORITIES.map(p => (
            <button
              key={p.value}
              type="button"
              onClick={() => { onChange(p.value); setOpen(false); }}
              className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors duration-150 text-left"
              style={{
                color: p.value === value ? p.color : 'var(--text-secondary)',
                background: p.value === value ? p.bg : 'transparent',
              }}
              onMouseEnter={e => { if (p.value !== value) (e.currentTarget as HTMLElement).style.background = 'var(--surface-2)'; }}
              onMouseLeave={e => { if (p.value !== value) (e.currentTarget as HTMLElement).style.background = 'transparent'; }}
            >
              <span className="w-2 h-2 rounded-full shrink-0" style={{ background: p.color }} />
              {p.label}
              {p.value === value && (
                <svg className="ml-auto" width="14" height="14" viewBox="0 0 14 14" fill="none">
                  <path d="M2.5 7l3 3 6-6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

/* ─── Status indicator ─── */
function StatusButton({ status, onClick }: { status: Status; onClick: (e: React.MouseEvent) => void }) {
  return (
    <button
      onClick={onClick}
      className="w-6 h-6 rounded-full flex items-center justify-center shrink-0 transition-all duration-300 group/btn"
      title={`Click to set: ${nextStatus(status)}`}
      style={{
        border: `2px solid ${
          status === 'Done' ? 'var(--text-muted)' :
          status === 'In Progress' ? 'var(--accent)' :
          'var(--border-strong)'
        }`,
        background:
          status === 'Done' ? 'var(--text-muted)' :
          status === 'In Progress' ? 'var(--accent-light)' :
          'transparent',
      }}
    >
      {status === 'Done' && (
        <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
          <path d="M2 5l2.5 2.5L8 3" stroke="white" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      )}
      {status === 'In Progress' && (
        <span
          className="w-2 h-2 rounded-full"
          style={{ background: 'var(--accent)' }}
        />
      )}
    </button>
  );
}

/* ─── Filter tabs ─── */
const FILTERS = [
  { key: 'All',     label: 'All' },
  { key: 'Me',      label: 'Mine' },
  { key: 'Partner', label: 'Partner\'s' },
  { key: 'Done',    label: 'Done' },
] as const;

type FilterKey = typeof FILTERS[number]['key'];

/* ─── Task Drawer ─── */
function TaskDrawer({
  task, onClose, onDelete, onUpdate,
}: {
  task: Task;
  onClose: () => void;
  onDelete: (id: string) => void;
  onUpdate: (t: Task) => void;
}) {
  const [notes, setNotes] = useState(task.notes || '');
  const [newSub, setNewSub] = useState('');
  const cfg = getPriority(task.priority);

  const addSubtask = () => {
    if (!newSub.trim()) return;
    const sub: Subtask = { id: crypto.randomUUID(), title: newSub, completed: false };
    onUpdate({ ...task, subtasks: [...task.subtasks, sub] });
    setNewSub('');
  };

  const toggleSub = (id: string) =>
    onUpdate({ ...task, subtasks: task.subtasks.map(s => s.id === id ? { ...s, completed: !s.completed } : s) });

  const saveNotes = () => onUpdate({ ...task, notes });

  const statusLabel: Record<Status, string> = {
    'Pending': 'Not started',
    'In Progress': 'In Progress',
    'Done': 'Completed',
  };

  return (
    <div className="fixed inset-0 z-[100] flex justify-end" onClick={onClose}>
      <div className="absolute inset-0 modal-backdrop" />
      <div
        className="relative w-full max-w-lg h-full flex flex-col"
        style={{
          background: 'var(--bg)',
          borderLeft: '1px solid var(--border-strong)',
          animation: 'slide-in-from-right 0.35s cubic-bezier(0.25,0.46,0.45,0.94) forwards',
        }}
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="px-8 pt-8 pb-6" style={{ borderBottom: '1px solid var(--border)' }}>
          <div className="flex items-start justify-between gap-4 mb-5">
            <span
              className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold"
              style={{ background: cfg.bg, color: cfg.color }}
            >
              <span className="w-1.5 h-1.5 rounded-full" style={{ background: cfg.color }} />
              {cfg.label}
            </span>
            <button
              onClick={onClose}
              className="w-8 h-8 rounded-full flex items-center justify-center transition-colors"
              style={{ color: 'var(--text-muted)', border: '1px solid var(--border)' }}
              onMouseEnter={e => ((e.currentTarget as HTMLElement).style.background = 'var(--surface-2)')}
              onMouseLeave={e => ((e.currentTarget as HTMLElement).style.background = 'transparent')}
            >
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                <path d="M1 1l12 12M13 1L1 13" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
              </svg>
            </button>
          </div>

          <h2
            className="leading-tight mb-5"
            style={{
              fontFamily: 'var(--font-playfair)',
              fontSize: '1.6rem',
              fontWeight: 500,
              color: 'var(--text-primary)',
            }}
          >
            {task.title}
          </h2>

          <div className="flex flex-wrap gap-6 text-xs">
            {[
              { label: 'Status', value: statusLabel[task.status] },
              { label: 'Assigned', value: task.assignedTo },
            ].map(({ label, value }) => (
              <div key={label}>
                <p className="mb-1.5 font-semibold tracking-widest uppercase" style={{ color: 'var(--text-muted)' }}>{label}</p>
                <p className="font-medium" style={{ color: 'var(--text-primary)' }}>{value}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-8 py-6 space-y-8">
          {/* Subtasks */}
          <div>
            <p className="text-xs font-semibold tracking-widest uppercase mb-4" style={{ color: 'var(--text-muted)' }}>
              Subtasks
              {task.subtasks.length > 0 && (
                <span className="ml-2 font-normal" style={{ color: 'var(--accent)' }}>
                  {task.subtasks.filter(s => s.completed).length}/{task.subtasks.length}
                </span>
              )}
            </p>
            <div className="space-y-2 mb-4">
              {task.subtasks.map(s => (
                <div key={s.id} className="flex items-center gap-3 cursor-pointer group py-1" onClick={() => toggleSub(s.id)}>
                  <div
                    className="w-5 h-5 rounded border flex items-center justify-center shrink-0 transition-all"
                    style={{
                      borderColor: s.completed ? 'var(--accent)' : 'var(--border-strong)',
                      background: s.completed ? 'var(--accent)' : 'transparent',
                    }}
                  >
                    {s.completed && (
                      <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                        <path d="M2 5l2.5 2.5L8 3" stroke="white" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                      </svg>
                    )}
                  </div>
                  <span
                    className="text-sm transition-all"
                    style={{ color: s.completed ? 'var(--text-muted)' : 'var(--text-primary)', textDecoration: s.completed ? 'line-through' : 'none' }}
                  >
                    {s.title}
                  </span>
                </div>
              ))}
            </div>
            <div
              className="flex items-center gap-2 rounded-xl px-4 py-2.5"
              style={{ border: '1px solid var(--border)', background: 'var(--surface)' }}
            >
              <input
                value={newSub}
                onChange={e => setNewSub(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && addSubtask()}
                placeholder="Add subtask..."
                className="flex-1 bg-transparent text-sm font-light outline-none"
                style={{ color: 'var(--text-primary)' }}
              />
              {newSub && (
                <button onClick={addSubtask} className="text-xs px-2.5 py-1 rounded-lg font-medium" style={{ background: 'var(--accent-light)', color: 'var(--accent)' }}>
                  Add
                </button>
              )}
            </div>
          </div>

          {/* Notes */}
          <div>
            <p className="text-xs font-semibold tracking-widest uppercase mb-4" style={{ color: 'var(--text-muted)' }}>Notes</p>
            <textarea
              value={notes}
              onChange={e => setNotes(e.target.value)}
              onBlur={saveNotes}
              rows={5}
              placeholder="Add context, links, or notes..."
              className="w-full rounded-2xl px-4 py-3 text-sm font-light resize-none"
              style={{
                border: '1px solid var(--border)',
                background: 'var(--surface)',
                color: 'var(--text-primary)',
                outline: 'none',
              }}
            />
          </div>
        </div>

        {/* Footer */}
        <div className="px-8 py-5 flex items-center justify-between" style={{ borderTop: '1px solid var(--border)' }}>
          <button
            onClick={() => { onDelete(task.id); onClose(); }}
            className="flex items-center gap-2 text-sm font-medium transition-opacity hover:opacity-70"
            style={{ color: '#E05C5C' }}
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M2 4h12M5 4V2h6v2M6 7v5M10 7v5M3 4l1 10h8l1-10" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            Delete
          </button>
        </div>
      </div>
    </div>
  );
}

/* ─── Main Tasks Page ─── */
export default function TasksPage() {
  const router = useRouter();
  const [activeUser, setActiveUser] = useState<User>('User A');
  const [tasks, setTasks] = useState<Task[]>([]);
  const [filter, setFilter] = useState<FilterKey>('All');
  const [selectedTask, setSelectedTask] = useState<Task | null>(null);
  const [mounted, setMounted] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newPriority, setNewPriority] = useState<Priority>('Medium');
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setMounted(true);
    const u = localStorage.getItem(STORAGE_KEYS.USER) as User;
    if (!u) { router.push('/login'); return; }
    setActiveUser(u);
    const theme = localStorage.getItem(STORAGE_KEYS.THEME) || 'dark';
    if (theme === 'dark') document.documentElement.classList.add('dark');
    else document.documentElement.classList.remove('dark');
    const saved = localStorage.getItem(STORAGE_KEYS.TASKS);
    setTasks(saved ? JSON.parse(saved) : MOCK_TASKS);
  }, [router]);

  useEffect(() => {
    if (!mounted) return;
    localStorage.setItem(STORAGE_KEYS.TASKS, JSON.stringify(tasks));
  }, [tasks, mounted]);

  const addTask = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim()) return;
    const t: Task = {
      id: crypto.randomUUID(),
      title: newTitle,
      priority: newPriority,
      status: 'Pending',
      assignedTo: activeUser,
      subtasks: [],
      createdAt: new Date().toISOString(),
    };
    setTasks(prev => [t, ...prev]);
    setNewTitle('');
    inputRef.current?.focus();
  };

  const cycleStatus = (id: string) =>
    setTasks(prev =>
      prev.map(t => t.id === id ? { ...t, status: nextStatus(t.status) } : t)
    );

  const updateTask = (updated: Task) => {
    setTasks(prev => prev.map(t => t.id === updated.id ? updated : t));
    setSelectedTask(updated);
  };

  const deleteTask = (id: string) => setTasks(prev => prev.filter(t => t.id !== id));

  if (!mounted) return null;

  const openCount = tasks.filter(t => t.status !== 'Done').length;
  const doneCount = tasks.filter(t => t.status === 'Done').length;

  // Filter logic
  const pendingTasks   = tasks.filter(t => t.status === 'Pending');
  const inProgTasks    = tasks.filter(t => t.status === 'In Progress');
  const doneTasks      = tasks.filter(t => t.status === 'Done');

  const applyFilter = (list: Task[]) => {
    if (filter === 'Me')      return list.filter(t => t.assignedTo === activeUser);
    if (filter === 'Partner') return list.filter(t => t.assignedTo !== activeUser);
    return list;
  };

  // Shown groups based on filter tab
  const showDoneOnly = filter === 'Done';

  const visiblePending  = showDoneOnly ? [] : applyFilter(pendingTasks);
  const visibleInProg   = showDoneOnly ? [] : applyFilter(inProgTasks);
  const visibleDone     = showDoneOnly ? applyFilter(doneTasks) : applyFilter(doneTasks);

  const TaskRow = ({ task }: { task: Task }) => {
    const cfg = getPriority(task.priority);
    const done = task.status === 'Done';
    const inProg = task.status === 'In Progress';

    return (
      <div
        className="flex items-center gap-4 px-4 py-4 rounded-2xl cursor-pointer group transition-all duration-200"
        style={{ border: '1px solid transparent' }}
        onMouseEnter={e => {
          (e.currentTarget as HTMLElement).style.background = 'var(--surface)';
          (e.currentTarget as HTMLElement).style.borderColor = 'var(--border)';
        }}
        onMouseLeave={e => {
          (e.currentTarget as HTMLElement).style.background = 'transparent';
          (e.currentTarget as HTMLElement).style.borderColor = 'transparent';
        }}
        onClick={() => setSelectedTask(task)}
      >
        <StatusButton
          status={task.status}
          onClick={e => { e.stopPropagation(); cycleStatus(task.id); }}
        />

        <p
          className="flex-1 text-base font-medium truncate transition-all"
          style={{
            color: done ? 'var(--text-muted)' : inProg ? 'var(--text-secondary)' : 'var(--text-primary)',
            textDecoration: done ? 'line-through' : 'none',
          }}
        >
          {task.title}
        </p>

        <div className="flex items-center gap-4 text-xs shrink-0">
          {task.subtasks.length > 0 && (
            <span style={{ color: 'var(--text-muted)' }}>
              {task.subtasks.filter(s => s.completed).length}/{task.subtasks.length}
            </span>
          )}
          <span className="font-semibold" style={{ color: cfg.color }}>{cfg.label}</span>
          <span style={{ color: 'var(--text-muted)' }}>
            {task.assignedTo === activeUser ? 'Me' : 'Partner'}
          </span>
          <svg
            className="opacity-0 group-hover:opacity-100 transition-opacity"
            width="14" height="14" viewBox="0 0 14 14" fill="none"
            style={{ color: 'var(--text-muted)' }}
          >
            <path d="M5 3l4 4-4 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen page-transition" style={{ background: 'var(--bg)' }}>
      <Nav activeUser={activeUser} setActiveUser={setActiveUser} />

      <main className="max-w-4xl mx-auto px-6 pt-28 pb-24">
        {/* ─── Header ─── */}
        <div className="mb-14">
          <p className="text-xs tracking-widest uppercase mb-3 font-semibold" style={{ color: 'var(--text-muted)' }}>
            {openCount} open · {doneCount} done
          </p>
          <h1
            className="leading-[1.0]"
            style={{
              fontFamily: 'var(--font-playfair)',
              fontSize: 'clamp(3rem, 6vw, 5rem)',
              fontWeight: 500,
              color: 'var(--text-primary)',
              letterSpacing: '-0.02em',
            }}
          >
            Tasks
          </h1>
        </div>

        {/* ─── Add task row ─── */}
        <form onSubmit={addTask} className="mb-10">
          <div className="flex items-center gap-3">
            {/* Input — no border box on focus, just underline animation */}
            <div className="flex-1 relative">
              <input
                ref={inputRef}
                type="text"
                value={newTitle}
                onChange={e => setNewTitle(e.target.value)}
                placeholder="New task..."
                className="w-full bg-transparent py-4 text-xl font-light border-b-2 outline-none transition-colors duration-300"
                style={{
                  borderColor: newTitle ? 'var(--accent)' : 'var(--border-strong)',
                  color: 'var(--text-primary)',
                  caretColor: 'var(--accent)',
                }}
                onFocus={e => (e.target.style.borderColor = 'var(--accent)')}
                onBlur={e => (e.target.style.borderColor = newTitle ? 'var(--accent)' : 'var(--border-strong)')}
              />
            </div>

            {/* Priority picker */}
            <PriorityPicker value={newPriority} onChange={setNewPriority} />

            {/* Submit button */}
            <button
              type="submit"
              disabled={!newTitle.trim()}
              className="w-10 h-10 rounded-full flex items-center justify-center shrink-0 transition-all duration-300"
              style={{
                background: newTitle.trim() ? 'var(--accent)' : 'var(--surface)',
                color: newTitle.trim() ? 'white' : 'var(--text-muted)',
                border: '1px solid var(--border)',
                transform: newTitle.trim() ? 'scale(1)' : 'scale(0.95)',
              }}
            >
              <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
                <path d="M9 3v12M3 9h12" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
              </svg>
            </button>
          </div>
        </form>

        {/* ─── Filter tabs — redesigned ─── */}
        <div className="flex items-center gap-1 mb-10">
          {FILTERS.map(f => {
            const active = filter === f.key;
            return (
              <button
                key={f.key}
                onClick={() => setFilter(f.key)}
                className="relative px-5 py-2 text-sm font-medium transition-all duration-300 rounded-full"
                style={{
                  color: active ? 'var(--text-primary)' : 'var(--text-muted)',
                  background: active ? 'var(--surface)' : 'transparent',
                  border: active ? '1px solid var(--border-strong)' : '1px solid transparent',
                }}
              >
                {f.label}
                {/* Active dot indicator */}
                {active && (
                  <span
                    className="absolute bottom-1 left-1/2 -translate-x-1/2 w-1 h-1 rounded-full"
                    style={{ background: 'var(--accent)' }}
                  />
                )}
              </button>
            );
          })}
        </div>

        {/* ─── Task groups ─── */}
        <div className="space-y-1">
          {/* Pending */}
          {visiblePending.map(task => <TaskRow key={task.id} task={task} />)}

          {/* In Progress — with section label if any exist */}
          {visibleInProg.length > 0 && (
            <>
              {(visiblePending.length > 0) && (
                <div className="flex items-center gap-4 py-4">
                  <div className="flex-1 h-px" style={{ background: 'var(--border)' }} />
                  <span className="text-xs font-semibold tracking-widest uppercase flex items-center gap-2" style={{ color: 'var(--accent)' }}>
                    <span className="w-1.5 h-1.5 rounded-full" style={{ background: 'var(--accent)' }} />
                    In Progress
                  </span>
                  <div className="flex-1 h-px" style={{ background: 'var(--border)' }} />
                </div>
              )}
              {visiblePending.length === 0 && (
                <div className="flex items-center gap-4 pb-4">
                  <span className="text-xs font-semibold tracking-widest uppercase flex items-center gap-2" style={{ color: 'var(--accent)' }}>
                    <span className="w-1.5 h-1.5 rounded-full animate-pulse" style={{ background: 'var(--accent)' }} />
                    In Progress
                  </span>
                </div>
              )}
              {visibleInProg.map(task => <TaskRow key={task.id} task={task} />)}
            </>
          )}

          {/* Divider before done */}
          {(visibleDone.length > 0 && !showDoneOnly && (visiblePending.length > 0 || visibleInProg.length > 0)) && (
            <div className="flex items-center gap-4 py-4">
              <div className="flex-1 h-px" style={{ background: 'var(--border)' }} />
              <span className="text-xs font-semibold tracking-widest uppercase" style={{ color: 'var(--text-muted)' }}>Completed</span>
              <div className="flex-1 h-px" style={{ background: 'var(--border)' }} />
            </div>
          )}
          {visibleDone.map(task => <TaskRow key={task.id} task={task} />)}

          {/* Empty state */}
          {visiblePending.length === 0 && visibleInProg.length === 0 && visibleDone.length === 0 && (
            <div className="py-20 text-center">
              <p className="text-5xl mb-4">✦</p>
              <p className="font-light" style={{ color: 'var(--text-muted)', fontSize: '1rem' }}>
                {filter === 'Done' ? 'Nothing completed yet.' : 'All clear. Nothing queued.'}
              </p>
            </div>
          )}
        </div>
      </main>

      {/* Task drawer */}
      {selectedTask && (
        <TaskDrawer
          task={selectedTask}
          onClose={() => setSelectedTask(null)}
          onDelete={deleteTask}
          onUpdate={updateTask}
        />
      )}
    </div>
  );
}
