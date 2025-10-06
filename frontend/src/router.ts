import {createRouter, createWebHistory} from 'vue-router';
import Login from './views/Login.vue';
import Dashboard from './views/Dashboard.vue';
import Tokens from './views/Tokens.vue';
import AuditLogs from './views/AuditLogs.vue';
import Users from './views/Users.vue';
import Profile from './views/Profile.vue';
import PageEditor from './views/PageEditor.vue';
import RoleManager from './views/RoleManager.vue';

const routes = [
    {path: '/', name: 'Login', component: Login},
    {path: '/login', redirect: {name: 'Login'}},
    {path: '/dashboard', name: 'Dashboard', component: Dashboard},
    {path: '/tokens', name: 'Tokens', component: Tokens},
    {path: '/logs', name: 'AuditLogs', component: AuditLogs},
    {path: '/users', name: 'Users', component: Users},
    {path: '/profile', name: 'Profile', component: Profile},
    {path: '/page-editor', name: 'PageEditor', component: PageEditor},
    {path: '/roles', name: 'RoleManager', component: RoleManager},
    {path: '/:pathMatch(.*)*', redirect: '/'},
];

export default createRouter({
    history: createWebHistory(),
    routes,
});
