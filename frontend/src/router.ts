import type {RouteRecordRaw} from 'vue-router';
import {createRouter, createWebHistory} from 'vue-router';
import Login from './views/Login.vue';
import Dashboard from './views/Dashboard.vue';
import AuditLogs from './views/AuditLogs.vue';
import PageEditor from './views/PageEditor.vue';
import ThemeSettings from './views/ThemeSettings.vue';

const routes: RouteRecordRaw[] = [
    {path: '/', name: 'Login', component: Login},
    {path: '/login', redirect: {name: 'Login'}},
    {path: '/dashboard', name: 'Dashboard', component: Dashboard},
    {path: '/logs', name: 'AuditLogs', component: AuditLogs},
    {path: '/page-editor', name: 'PageEditor', component: PageEditor},
    {path: '/theme', name: 'ThemeSettings', component: ThemeSettings, meta: {requiredPermission: 'manage_theme'}},
    {path: '/:pathMatch(.*)*', redirect: '/'},
];

const router = createRouter({
    history: createWebHistory(import.meta.env.BASE_URL),
    routes,
});

// Minimal permission guard using window/localStorage permissions array
router.beforeEach((to, _from, next) => {
    const required = (to.meta as any)?.requiredPermission as string | undefined;
    if (!required) return next();
    // @ts-ignore
    const perms = (window as any).__USER_PERMISSIONS__ || (() => {
        try {
            return JSON.parse(localStorage.getItem('user_permissions') || '[]');
        } catch {
            return [];
        }
    })();
    if (Array.isArray(perms) && perms.includes(required)) return next();
    // If not authorized, redirect to dashboard (or login)
    return next({name: 'Dashboard'});
});

export default router;
