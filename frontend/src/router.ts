import type {RouteRecordRaw} from 'vue-router';
import {createRouter, createWebHistory} from 'vue-router';
import Login from './views/Login.vue';
import Dashboard from './views/Dashboard.vue';
import Tokens from './views/Tokens.vue';
import AuditLogs from './views/AuditLogs.vue';
import Users from './views/Users.vue';
import Profile from './views/Profile.vue';
import PageEditor from './views/PageEditor.vue';
import RoleManager from './views/RoleManager.vue';
import Messenger from './views/Messenger.vue';
import Notifications from './views/Notifications.vue';
import ThemeSettings from './views/ThemeSettings.vue';

const routes: RouteRecordRaw[] = [
    {path: '/', name: 'Login', component: Login},
    {path: '/login', redirect: {name: 'Login'}},
    {path: '/dashboard', name: 'Dashboard', component: Dashboard},
    {path: '/tokens', name: 'Tokens', component: Tokens},
    {path: '/logs', name: 'AuditLogs', component: AuditLogs},
    {path: '/users', name: 'Users', component: Users},
    {path: '/profile', name: 'Profile', component: Profile},
    {path: '/page-editor', name: 'PageEditor', component: PageEditor},
    {path: '/roles', name: 'RoleManager', component: RoleManager},
    {path: '/messenger', name: 'Messenger', component: Messenger},
    {path: '/notifications', name: 'Notifications', component: Notifications},
    {path: '/settings/theme', name: 'ThemeSettings', component: ThemeSettings},
    {path: '/:pathMatch(.*)*', redirect: '/'},
];

export default createRouter({
    history: createWebHistory((import.meta as any)?.env?.BASE_URL || '/'),
    routes,
});
