'use client';
import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import Nav from '@/components/Nav';
import { STORAGE_KEYS, User, Note } from '@/lib/types';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';

const DEFAULT_NOTES: Note[] = [
  {
    id: '1',
    title: 'Shared Vision & Goals',
    content: '# Our Roadmap\n\nA space for our long-term plans.\n\n## 2027 Goals\n- Travel to Japan\n- Start a new project together',
    updatedAt: new Date().toISOString(),
    lastEditedBy: 'User A',
  },
  {
    id: '2',
    title: 'Home Renovation',
    content: 'Ideas for the living room:\n- New rug (warm tones)\n- Bookshelves on the west wall\n\n*Measurements attached below*',
    updatedAt: new Date().toISOString(),
    lastEditedBy: 'User B',
  }
];

export default function NotesPage() {
  const router = useRouter();
  const [activeUser, setActiveUser] = useState<User>('User A');
  const [notes, setNotes] = useState<Note[]>([]);
  const [activeNoteId, setActiveNoteId] = useState<string | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [mounted, setMounted] = useState(false);
  
  // Refs to track if we need to focus newly created note title
  const titleInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setMounted(true);
    const u = localStorage.getItem(STORAGE_KEYS.USER) as User;
    if (!u) { router.push('/login'); return; }
    setActiveUser(u);
    const theme = localStorage.getItem(STORAGE_KEYS.THEME) || 'dark';
    if (theme === 'dark') document.documentElement.classList.add('dark');
    else document.documentElement.classList.remove('dark');
    
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.NOTES);
      if (saved) {
        const parsed = JSON.parse(saved);
        if (Array.isArray(parsed)) {
          setNotes(parsed);
          if (parsed.length > 0) setActiveNoteId(parsed[0].id);
        } else {
          // Legacy string migration
          const legacyNote: Note = {
            id: crypto.randomUUID(),
            title: 'Legacy Note',
            content: saved,
            updatedAt: new Date().toISOString(),
            lastEditedBy: u,
          };
          setNotes([legacyNote, ...DEFAULT_NOTES]);
          setActiveNoteId(legacyNote.id);
        }
      } else {
        setNotes(DEFAULT_NOTES);
        setActiveNoteId(DEFAULT_NOTES[0].id);
      }
    } catch (e) {
      setNotes(DEFAULT_NOTES);
      setActiveNoteId(DEFAULT_NOTES[0].id);
    }
  }, [router]);

  useEffect(() => {
    if (!mounted) return;
    localStorage.setItem(STORAGE_KEYS.NOTES, JSON.stringify(notes));
  }, [notes, mounted]);

  const activeNote = notes.find(n => n.id === activeNoteId);

  const createNote = () => {
    const newNote: Note = {
      id: crypto.randomUUID(),
      title: 'Untitled Note',
      content: '',
      updatedAt: new Date().toISOString(),
      lastEditedBy: activeUser,
    };
    setNotes(prev => [newNote, ...prev]);
    setActiveNoteId(newNote.id);
    setIsEditing(true);
    setTimeout(() => titleInputRef.current?.focus(), 100);
  };

  const selectNote = (id: string) => {
    setActiveNoteId(id);
    setIsEditing(false); // Always reset to preview when changing notes
  };

  const deleteNote = (id: string) => {
    setNotes(prev => {
      const filtered = prev.filter(n => n.id !== id);
      if (activeNoteId === id) {
        setActiveNoteId(filtered.length > 0 ? filtered[0].id : null);
        setIsEditing(false);
      }
      return filtered;
    });
  };

  const updateActiveNote = (updates: Partial<Note>) => {
    setNotes(prev =>
      prev.map(n =>
        n.id === activeNoteId
          ? { ...n, ...updates, updatedAt: new Date().toISOString(), lastEditedBy: activeUser }
          : n
      )
    );
  };

  // Format date elegantly
  const formatDate = (isoStr: string) => {
    const d = new Date(isoStr);
    return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }).format(d);
  };

  if (!mounted) return null;

  return (
    <div className="min-h-screen page-transition flex flex-col" style={{ background: 'var(--bg)' }}>
      <Nav activeUser={activeUser} setActiveUser={setActiveUser} />

      <main className="flex-1 max-w-[1400px] mx-auto w-full px-6 pt-28 pb-12 flex h-[100vh]">
        
        {/* ── Left Sidebar (Note List) - Now with Lines instead of Boxes ── */}
        <div className="w-[320px] flex flex-col h-full shrink-0 pr-8" style={{ borderRight: '1px solid var(--border)' }}>
          <div className="flex items-center justify-between mb-10 pl-2">
            <h1
              className="leading-[1.0]"
              style={{
                fontFamily: 'var(--font-playfair)',
                fontSize: '2.5rem',
                fontWeight: 500,
                color: 'var(--text-primary)',
                letterSpacing: '-0.02em',
              }}
            >
              Notes
            </h1>
            <button
              onClick={createNote}
              className="w-8 h-8 rounded-full flex items-center justify-center transition-all duration-300 hover:scale-105"
              style={{
                background: 'transparent',
                color: 'var(--text-primary)',
                border: '1px solid var(--border-strong)',
              }}
              title="New Note"
            >
              <svg width="14" height="14" viewBox="0 0 18 18" fill="none">
                <path d="M9 3v12M3 9h12" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/>
              </svg>
            </button>
          </div>

          <div className="flex-1 overflow-y-auto custom-scrollbar pb-10">
            {notes.map(note => {
              const active = note.id === activeNoteId;
              const isUserA = note.lastEditedBy === 'User A';
              return (
                <button
                  key={note.id}
                  onClick={() => selectNote(note.id)}
                  className="w-full text-left py-5 pl-2 pr-4 transition-all duration-300 group relative flex flex-col"
                  style={{ borderBottom: '1px solid var(--border)' }}
                >
                  {/* Subtle active indicator line */}
                  <div 
                    className="absolute left-0 top-1/2 -translate-y-1/2 w-[3px] h-0 rounded-r-full transition-all duration-300"
                    style={{
                      background: isUserA 
                        ? 'linear-gradient(to bottom, #E8A87C, #C4813A)' 
                        : 'linear-gradient(to bottom, #D48FAD, #B5638A)',
                      height: active ? '40%' : '0%',
                      opacity: active ? 1 : 0,
                    }}
                  />
                  
                  <div className="flex items-start justify-between gap-2 mb-1.5 pl-3">
                    <p
                      className="truncate transition-colors"
                      style={{
                        color: active ? 'var(--text-primary)' : 'var(--text-secondary)',
                        fontFamily: 'var(--font-playfair)',
                        fontSize: '1.2rem',
                        fontWeight: active ? 500 : 400,
                      }}
                    >
                      {note.title || 'Untitled'}
                    </p>
                  </div>
                  <div className="flex items-center gap-2 pl-3">
                    <p className="text-[11px] font-light tracking-widest uppercase" style={{ color: 'var(--text-muted)' }}>
                      {formatDate(note.updatedAt)}
                    </p>
                  </div>
                </button>
              );
            })}

            {notes.length === 0 && (
              <div className="py-10 text-center pl-2">
                <p className="font-light text-sm" style={{ color: 'var(--text-muted)' }}>No notes yet.</p>
              </div>
            )}
          </div>
        </div>

        {/* ── Right Canvas (Editor/Preview) - Flat design ── */}
        <div className="flex-1 flex flex-col h-full pl-12 pb-10">
          {activeNote ? (
            <div className="flex-1 flex flex-col relative h-full">
              {/* Toolbar */}
              <div className="h-16 flex items-center justify-between shrink-0 mb-6">
                
                {/* Elegant author indicator */}
                <div className="flex items-center gap-3">
                  {activeNote.lastEditedBy && (
                    <>
                      <div 
                        className="w-2 h-2 rounded-full"
                        style={{
                          background: activeNote.lastEditedBy === 'User A' 
                            ? 'linear-gradient(135deg, #E8A87C, #C4813A)'
                            : 'linear-gradient(135deg, #D48FAD, #B5638A)',
                          boxShadow: activeNote.lastEditedBy === 'User A'
                            ? '0 0 10px rgba(232,168,124,0.4)'
                            : '0 0 10px rgba(212,143,173,0.4)'
                        }}
                      />
                      <span className="text-[11px] uppercase tracking-widest font-light" style={{ color: 'var(--text-muted)' }}>
                        Edited by {activeNote.lastEditedBy}
                      </span>
                    </>
                  )}
                </div>

                <div className="flex items-center gap-6">
                  {/* Mode Toggles (Lines, not boxes) */}
                  <div className="flex items-center gap-6 relative">
                    {['Preview', 'Edit'].map(mode => {
                      const isActive = (mode === 'Edit' && isEditing) || (mode === 'Preview' && !isEditing);
                      return (
                        <button
                          key={mode}
                          onClick={() => setIsEditing(mode === 'Edit')}
                          className="pb-1 text-xs font-semibold tracking-widest uppercase transition-all duration-300 relative"
                          style={{
                            color: isActive ? 'var(--text-primary)' : 'var(--text-muted)',
                          }}
                        >
                          {mode}
                          {/* Active Underline */}
                          <div 
                            className="absolute -bottom-[1px] left-0 right-0 h-[1px] transition-all duration-300"
                            style={{
                              background: 'var(--text-primary)',
                              opacity: isActive ? 1 : 0,
                              transform: isActive ? 'scaleX(1)' : 'scaleX(0)',
                            }}
                          />
                        </button>
                      );
                    })}
                  </div>

                  <div className="w-[1px] h-4 bg-[var(--border)]" />

                  <button
                    onClick={() => deleteNote(activeNote.id)}
                    className="text-xs tracking-widest uppercase transition-colors hover:text-red-400"
                    style={{ color: 'var(--text-muted)' }}
                  >
                    Delete
                  </button>
                </div>
              </div>

              {/* Title Section */}
              <div className="pb-8 shrink-0">
                {isEditing ? (
                  <input
                    ref={titleInputRef}
                    type="text"
                    value={activeNote.title}
                    onChange={e => updateActiveNote({ title: e.target.value })}
                    placeholder="Note Title..."
                    className="w-full bg-transparent outline-none transition-colors duration-300 placeholder:opacity-30"
                    style={{
                      fontFamily: 'var(--font-playfair)',
                      fontSize: 'clamp(2.5rem, 5vw, 4rem)',
                      fontWeight: 500,
                      color: 'var(--text-primary)',
                      letterSpacing: '-0.02em',
                      borderBottom: '1px solid var(--border)',
                      paddingBottom: '1rem',
                    }}
                  />
                ) : (
                  <h1
                    className="w-full"
                    style={{
                      fontFamily: 'var(--font-playfair)',
                      fontSize: 'clamp(2.5rem, 5vw, 4rem)',
                      fontWeight: 500,
                      color: 'var(--text-primary)',
                      letterSpacing: '-0.02em',
                      borderBottom: '1px solid var(--border)',
                      paddingBottom: '1rem',
                      lineHeight: '1.2',
                    }}
                  >
                    {activeNote.title || 'Untitled'}
                  </h1>
                )}
              </div>

              {/* Body */}
              <div className="flex-1 overflow-y-auto custom-scrollbar relative">
                
                {/* Subtle author color line on the left side of the editor to show who owns this version */}
                <div 
                  className="absolute left-0 top-2 bottom-8 w-[1px] opacity-30"
                  style={{
                    background: activeNote.lastEditedBy === 'User A' 
                      ? 'linear-gradient(to bottom, #E8A87C, transparent)'
                      : 'linear-gradient(to bottom, #D48FAD, transparent)',
                  }}
                />

                <div className="pl-6 h-full">
                  {isEditing ? (
                    <textarea
                      value={activeNote.content}
                      onChange={e => updateActiveNote({ content: e.target.value })}
                      placeholder="Start typing..."
                      className="w-full h-full min-h-[500px] bg-transparent outline-none resize-none text-base leading-relaxed font-light"
                      style={{
                        fontFamily: 'var(--font-dm-sans)',
                        color: 'var(--text-secondary)',
                      }}
                    />
                  ) : (
                    <article
                      className="prose max-w-none pb-20"
                      style={{
                        '--tw-prose-body': 'var(--text-secondary)',
                        '--tw-prose-headings': 'var(--text-primary)',
                        '--tw-prose-bold': 'var(--text-primary)',
                        '--tw-prose-links': 'var(--accent)',
                        '--tw-prose-code': 'var(--accent)',
                        '--tw-prose-hr': 'var(--border)',
                        fontFamily: 'var(--font-dm-sans)',
                      } as React.CSSProperties}
                    >
                      {activeNote.content ? (
                        <ReactMarkdown remarkPlugins={[remarkGfm]}>{activeNote.content}</ReactMarkdown>
                      ) : (
                        <p className="opacity-40 italic">Empty note. Switch to Edit to add content.</p>
                      )}
                    </article>
                  )}
                </div>
              </div>
            </div>
          ) : (
            <div className="flex-1 flex flex-col items-center justify-center opacity-40">
              <p className="text-4xl mb-4" style={{ fontFamily: 'var(--font-playfair)' }}>✦</p>
              <p className="font-light tracking-widest uppercase text-xs">Select or create a note</p>
            </div>
          )}
        </div>
      </main>

      <style jsx global>{`
        .custom-scrollbar::-webkit-scrollbar {
          width: 4px;
        }
        .custom-scrollbar::-webkit-scrollbar-track {
          background: transparent;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb {
          background: var(--border-strong);
          border-radius: 99px;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover {
          background: var(--text-muted);
        }
      `}</style>
    </div>
  );
}
