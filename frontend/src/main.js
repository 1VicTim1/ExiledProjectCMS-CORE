import {createApp} from 'vue'
import App from './App.vue'
import router from './router'
import {loadTheme} from './stores/theme'

// Load theme ASAP (non-blocking)
loadTheme()

const app = createApp(App)
// Provide UI permissions globally as a simple array; components fall back safely if not overridden
app.provide('userPermissions', [])
app.use(router)
app.mount('#app')

