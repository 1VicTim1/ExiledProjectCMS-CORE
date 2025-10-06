// Simple theme store without external dependencies (no Pinia required)
// Manages theme colors, applies CSS variables, persists to localStorage, syncs with backend if available

import {themeAPI} from '../utils/api';

export type ThemeColors = {
    primary: string;
    secondary: string;
    accent: string;
    error: string;
    warning: string;
    info: string;
    success: string;
    background: string;
    surface: string;
    // allow additional properties
    [key: string]: string;
};

export const defaultTheme: ThemeColors = {
    primary: '#8B5CF6',
    secondary: '#7C3AED',
    accent: '#A78BFA',
    error: '#EF4444',
    warning: '#F59E0B',
    info: '#3B82F6',
    success: '#10B981',
    background: '#1F1F23',
    surface: '#2D2D33',
    text: '#FFFFFF',
};

let currentTheme: ThemeColors = {...defaultTheme};

export function getTheme(): ThemeColors {
    return {...currentTheme};
}

export function applyTheme(theme: ThemeColors = currentTheme) {
    const root = document.documentElement;
    Object.entries(theme).forEach(([key, value]) => {
        root.style.setProperty(`--color-${key}`, value);
    });
}

export async function loadTheme(): Promise<ThemeColors> {
    // Try server first
    try {
        const serverTheme = await themeAPI.get();
        if (serverTheme && typeof serverTheme === 'object') {
            currentTheme = {...defaultTheme, ...normalizeTheme(serverTheme)};
            localStorage.setItem('exiled-theme', JSON.stringify(currentTheme));
            applyTheme();
            return getTheme();
        }
    } catch {
        // ignore network/404
    }
    // Fallback to localStorage
    const saved = localStorage.getItem('exiled-theme');
    if (saved) {
        try {
            const parsed = JSON.parse(saved);
            currentTheme = {...defaultTheme, ...normalizeTheme(parsed)};
            applyTheme();
            return getTheme();
        } catch { /* ignore */
        }
    }
    // Defaults
    currentTheme = {...defaultTheme};
    applyTheme();
    return getTheme();
}

export async function updateTheme(partial: Partial<ThemeColors>, persist = true): Promise<ThemeColors> {
    currentTheme = {...currentTheme, ...partial};
    applyTheme();
    localStorage.setItem('exiled-theme', JSON.stringify(currentTheme));
    if (persist) {
        try {
            await themeAPI.update(currentTheme);
        } catch {
            // If backend not ready, keep local only
        }
    }
    return getTheme();
}

export function resetTheme(persist = true): Promise<ThemeColors> {
    return updateTheme({...defaultTheme}, persist);
}

function normalizeTheme(obj: Record<string, any>): ThemeColors {
    const out: any = {};
    Object.keys(defaultTheme).forEach((k) => {
        if (obj[k]) out[k] = String(obj[k]);
    });
    // include any extra keys that look like colors
    Object.keys(obj).forEach((k) => {
        if (!(k in out) && typeof obj[k] === 'string' && obj[k].startsWith('#')) out[k] = obj[k];
    });
    return out as ThemeColors;
}
