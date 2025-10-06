import {createApp} from 'vue'
import App from './App.vue'
import router from './router'
import {loadTheme} from './stores/theme'

const app = createApp(App)

// Initialize theme early
loadTheme()

// Load user permissions from localStorage (expected to be JSON array of codes)
const storedPerms = (() => {
    try {
        return JSON.parse(localStorage.getItem('user_permissions') || '[]')
    } catch {
        return []
    }
})()

// Expose permissions via provide/inject and window for non-Vue modules (e.g., router guards)
app.provide('userPermissions', storedPerms)
// @ts-ignore
window.__USER_PERMISSIONS__ = storedPerms

app.use(router)
app.mount('#app')

