export type User = 'User A' | 'User B';
export type Priority = 'Low' | 'Medium' | 'High' | 'Urgent';
export type Status = 'Pending' | 'In Progress' | 'Done';
export type CalendarMode = 'pursuit' | 'port';

export interface Subtask {
  id: string;
  title: string;
  completed: boolean;
}

export interface Task {
  id: string;
  title: string;
  priority: Priority;
  status: Status;
  assignedTo: User;
  subtasks: Subtask[];
  notes?: string;
  dueDate?: string;
  createdAt: string;
}

export interface CalendarEvent {
  id: string;
  title: string;
  date: string;        // ISO date string YYYY-MM-DD
  startTime?: string;  // HH:MM
  endTime?: string;    // HH:MM
  location?: string;
  description?: string;
  user: User;
  mode: CalendarMode;  // 'pursuit' or 'port'
  emoji?: string;
}

export interface Reminder {
  id: string;
  title: string;
  datetime: string;
  user: User;
  done: boolean;
}

export interface Note {
  id: string;
  title: string;
  content: string;
  updatedAt: string;
  lastEditedBy?: User;
}

// Shared app state stored in localStorage
export const STORAGE_KEYS = {
  USER: 'forecast_user',
  THEME: 'forecast_theme',
  TASKS: 'forecast_tasks',
  EVENTS: 'forecast_events',
  REMINDERS: 'forecast_reminders',
  NOTES: 'forecast_notes',
};

export const MOCK_TASKS: Task[] = [
  { id: '1', title: 'Review Q3 project goals', priority: 'High', status: 'Pending', assignedTo: 'User A', subtasks: [], createdAt: new Date().toISOString() },
  { id: '2', title: 'Plan weekend grocery run', priority: 'Medium', status: 'Pending', assignedTo: 'User B', subtasks: [], createdAt: new Date().toISOString() },
  { id: '3', title: 'Update shared calendar', priority: 'Low', status: 'Done', assignedTo: 'User A', subtasks: [], createdAt: new Date().toISOString() },
];

export const MOCK_EVENTS: CalendarEvent[] = [
  { id: 'e1', title: 'Anniversary Dinner 🕯️', date: new Date(new Date().setDate(new Date().getDate() + 5)).toISOString().split('T')[0], startTime: '19:00', endTime: '22:00', location: 'La Maison Restaurant', description: 'Our special anniversary dinner reservation. Dress code: Smart casual.', user: 'User A', mode: 'port', emoji: '🕯️' },
  { id: 'e2', title: 'Project Launch Deadline', date: new Date(new Date().setDate(new Date().getDate() + 3)).toISOString().split('T')[0], startTime: '09:00', user: 'User A', mode: 'pursuit', description: 'Final deliverable due for Project Alpha.', emoji: '🚀' },
  { id: 'e3', title: 'Movie Night 🎬', date: new Date(new Date().setDate(new Date().getDate() + 8)).toISOString().split('T')[0], startTime: '20:00', location: 'Home', user: 'User B', mode: 'port', emoji: '🎬' },
  { id: 'e4', title: 'Weekly Review', date: new Date(new Date().setDate(new Date().getDate() + 1)).toISOString().split('T')[0], startTime: '10:00', user: 'User B', mode: 'pursuit', description: 'Weekly team sync and personal review session.', emoji: '📋' },
];

export const MOCK_REMINDERS: Reminder[] = [
  { id: 'r1', title: 'Call the restaurant to confirm reservation', datetime: new Date(new Date().setHours(new Date().getHours() + 2)).toISOString(), user: 'User A', done: false },
  { id: 'r2', title: 'Take evening vitamins', datetime: new Date(new Date().setHours(21, 0, 0, 0)).toISOString(), user: 'User B', done: false },
];
