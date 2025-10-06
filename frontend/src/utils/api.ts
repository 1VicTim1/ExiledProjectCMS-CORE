// Lightweight API client using fetch with JSON handling
// Ensures Authorization header from localStorage token if present

const API_BASE: string = (import.meta as any).env?.VITE_API_BASE_URL || '';

function withBase(path: string): string {
    if (!API_BASE) return path; // same origin
    // avoid double slashes
    return API_BASE.replace(/\/$/, '') + path;
}

async function request(path: string, options: RequestInit = {}) {
    const token = localStorage.getItem('auth_token') || localStorage.getItem('token');
    const headers: Record<string, string> = {
        'Accept': 'application/json',
        ...(options.body && typeof options.body !== 'string' ? {'Content-Type': 'application/json'} : {}),
        ...(options.headers as Record<string, string> || {}),
    };
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const res = await fetch(withBase(path), {...options, headers});
    const text = await res.text();
    let data: any = null;
    try {
        data = text ? JSON.parse(text) : null;
    } catch {
        data = text;
    }
    if (!res.ok) {
        const err: any = new Error(data?.message || `HTTP ${res.status}`);
        err.status = res.status;
        err.data = data;
        throw err;
    }
    return data;
}

export const themeAPI = {
    get: () => request('/api/theme', {method: 'GET'}),
    update: (payload: any) => request('/api/theme', {method: 'PUT', body: JSON.stringify(payload)}),
};

export const auditAPI = {
    getLogs: (params: Record<string, any> = {}) => {
        const qs = new URLSearchParams(Object.entries(params).filter(([, v]) => v !== undefined && v !== null && v !== '') as any).toString();
        return request(`/api/audit-logs${qs ? `?${qs}` : ''}`, {method: 'GET'});
    },
    deleteLogs: (params: Record<string, any> = {}) => {
        const qs = new URLSearchParams(Object.entries(params).filter(([, v]) => v !== undefined && v !== null && v !== '') as any).toString();
        return request(`/api/audit-logs${qs ? `?${qs}` : ''}`, {method: 'DELETE'});
    }
};

export const authAPI = {
    login: (credentials: { login: string; password: string }) => request('/api/web/login', {
        method: 'POST',
        body: JSON.stringify(credentials)
    }),
};

export type {};
