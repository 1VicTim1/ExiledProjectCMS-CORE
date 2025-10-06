// Lightweight theme store without external deps (Pinia-free)
// Provides dynamic CSS variables and persistence via backend /api/theme

export type Theme = {
    primary: string
    secondary: string
    accent: string
    error: string
    warning: string
    info: string
    success: string
    background: string
    surface: string
}

const DEFAULT_THEME: Theme = {
    primary: '#8B5CF6',
    secondary: '#7C3AED',
    accent: '#A78BFA',
    error: '#EF4444',
    warning: '#F59E0B',
    info: '#3B82F6',
    success: '#10B981',
    background: '#1F1F23',
    surface: '#2D2D33',
}

let currentTheme: Theme = {...DEFAULT_THEME}

const API_BASE = (import.meta as any)?.env?.VITE_API_BASE_URL || window.location.origin || ''

function setCssVars(theme: Theme) {
    const root = document.documentElement
    root.style.setProperty('--color-primary', theme.primary)
    root.style.setProperty('--color-secondary', theme.secondary)
    root.style.setProperty('--color-accent', theme.accent)
    root.style.setProperty('--color-error', theme.error)
    root.style.setProperty('--color-warning', theme.warning)
    root.style.setProperty('--color-info', theme.info)
    root.style.setProperty('--color-success', theme.success)
    root.style.setProperty('--color-background', theme.background)
    root.style.setProperty('--color-surface', theme.surface)
    // Bootstrap variables for better integration
    root.style.setProperty('--bs-primary', theme.primary)
    root.style.setProperty('--bs-body-bg', theme.background)
    root.style.setProperty('--bs-body-color', '#ffffff')
}

export function applyTheme(theme: Theme) {
    currentTheme = {...currentTheme, ...theme}
    setCssVars(currentTheme)
}

export function getTheme(): Theme {
    return {...currentTheme}
}

export async function loadTheme(): Promise<Theme> {
    try {
    // Try server first
        const r = await fetch(`${API_BASE}/api/theme`)
        if (r.ok) {
            const serverTheme = await r.json()
            // Normalise keys from server (Title-case vs camel-case)
            const normalized: Theme = {
                primary: serverTheme.primary ?? serverTheme.Primary ?? DEFAULT_THEME.primary,
                secondary: serverTheme.secondary ?? serverTheme.Secondary ?? DEFAULT_THEME.secondary,
                accent: serverTheme.accent ?? serverTheme.Accent ?? DEFAULT_THEME.accent,
                error: serverTheme.error ?? serverTheme.Error ?? DEFAULT_THEME.error,
                warning: serverTheme.warning ?? serverTheme.Warning ?? DEFAULT_THEME.warning,
                info: serverTheme.info ?? serverTheme.Info ?? DEFAULT_THEME.info,
                success: serverTheme.success ?? serverTheme.Success ?? DEFAULT_THEME.success,
                background: serverTheme.background ?? serverTheme.Background ?? DEFAULT_THEME.background,
                surface: serverTheme.surface ?? serverTheme.Surface ?? DEFAULT_THEME.surface,
            }
            applyTheme(normalized)
            localStorage.setItem('exiled-theme', JSON.stringify(normalized))
            return normalized
        }
    } catch (e) {
        // ignore, fallback below
    }
    // Fallback to localStorage or defaults
    const saved = localStorage.getItem('exiled-theme')
    const theme = saved ? {...DEFAULT_THEME, ...JSON.parse(saved)} : DEFAULT_THEME
    applyTheme(theme)
    return theme
}

export async function updateTheme(newTheme: Partial<Theme>, persist = false): Promise<Theme> {
    const merged = {...currentTheme, ...newTheme}
    applyTheme(merged)
    localStorage.setItem('exiled-theme', JSON.stringify(merged))

    if (persist) {
    try {
        // Server may expect PascalCase
        const payload = {
            Primary: merged.primary,
            Secondary: merged.secondary,
            Accent: merged.accent,
            Error: merged.error,
            Warning: merged.warning,
            Info: merged.info,
            Success: merged.success,
            Background: merged.background,
            Surface: merged.surface,
        }
        const r = await fetch(`${API_BASE}/api/theme`, {
            method: 'PUT',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(payload),
        })
        if (!r.ok) throw new Error('Failed to persist theme')
    } catch (e) {
        console.warn('Theme persist failed:', e)
    }
    }
    return merged
}

export async function resetTheme(persist = false): Promise<Theme> {
    applyTheme(DEFAULT_THEME)
    localStorage.setItem('exiled-theme', JSON.stringify(DEFAULT_THEME))
    if (persist) {
        await updateTheme(DEFAULT_THEME, true)
    }
    return {...DEFAULT_THEME}
}
