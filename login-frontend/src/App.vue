<template>
  <div class="container">
    <h1>Вход</h1>
    <form v-if="step==='login'" @submit.prevent="login">
      <label>Логин</label>
      <input v-model="loginForm.login" autocomplete="username" required>
      <label>Пароль</label>
      <input v-model="loginForm.password" autocomplete="current-password" required type="password">
      <button :disabled="loading">Войти</button>
      <div v-if="error" class="error">{{ error }}</div>
    </form>
    <div v-else-if="step==='setup-2fa'" class="setup2fa">
      <h2>Привязка 2FA</h2>
      <div v-if="qrCode">
        <img :src="qrCode" alt="QR-код 2FA">
        <div class="note">Секрет: {{ secret }}</div>
      </div>
      <div class="note">Отсканируйте QR-код в Google Authenticator, затем введите 6-значный код ниже.</div>
      <form @submit.prevent="verify2fa">
        <input v-model="code" maxlength="6" placeholder="123456" required>
        <button :disabled="loading">Подтвердить</button>
      </form>
      <div v-if="error" class="error">{{ error }}</div>
      <div v-if="success" class="success">{{ success }}</div>
    </div>
    <div v-else-if="step==='enter-2fa'" class="enter2fa">
      <h2>Введите код 2FA</h2>
      <form @submit.prevent="verify2fa">
        <input v-model="code" maxlength="6" placeholder="123456" required>
        <button :disabled="loading">Войти</button>
      </form>
      <div v-if="error" class="error">{{ error }}</div>
      <div v-if="success" class="success">{{ success }}</div>
    </div>
  </div>
</template>

<script setup>
import {ref} from 'vue'

const API = import.meta.env.VITE_API_BASE_URL || ''

const step = ref('login')
const loginForm = ref({login: '', password: ''})
const code = ref('')
const error = ref('')
const success = ref('')
const loading = ref(false)
const qrCode = ref('')
const secret = ref('')

async function login() {
  error.value = ''
  loading.value = true
  try {
    const r = await fetch(`${API}/api/web/login`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(loginForm.value)
    })
    const t = await r.json().catch(() => ({}))
    if (r.status === 200) {
      success.value = 'Успешная авторизация'
      setTimeout(() => window.location.reload(), 1000)
    } else if (t.next === 'setup-2fa') {
      await start2fa()
    } else if (t.next === 'enter-2fa') {
      step.value = 'enter-2fa'
    } else {
      error.value = t.message || `Ошибка: ${r.status}`
    }
  } catch (e) {
    error.value = 'Ошибка сети'
  }
  loading.value = false
}

async function start2fa() {
  error.value = ''
  loading.value = true
  try {
    const r = await fetch(`${API}/api/web/2fa/start`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({login: loginForm.value.login, issuer: 'ExiledCMS'})
    })
    const t = await r.json()
    qrCode.value = t.qrCodeDataUrl
    secret.value = t.secret
    step.value = 'setup-2fa'
  } catch {
    error.value = 'Ошибка генерации QR-кода'
  }
  loading.value = false
}

async function verify2fa() {
  error.value = ''
  success.value = ''
  loading.value = true
  try {
    const r = await fetch(`${API}/api/web/2fa/verify`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({login: loginForm.value.login, code: code.value})
    })
    const t = await r.json().catch(() => ({}))
    if (r.ok) {
      success.value = '2FA успешно привязана'
      setTimeout(() => window.location.reload(), 1000)
    } else {
      error.value = t.Message || 'Неверный код'
    }
  } catch {
    error.value = 'Ошибка сети'
  }
  loading.value = false
}
</script>

<style scoped>
.container {
  max-width: 420px;
  margin: 8vh auto;
  background: #111827;
  padding: 24px;
  border-radius: 12px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, .35);
  color: #e2e8f0;
}

h1, h2 {
  color: #f8fafc;
  margin-bottom: 14px;
}

label {
  display: block;
  font-size: 14px;
  margin: 12px 0 6px;
  color: #cbd5e1;
}

input {
  width: 100%;
  padding: 10px 12px;
  border-radius: 8px;
  border: 1px solid #334155;
  background: #0b1220;
  color: #e2e8f0;
  margin-bottom: 10px;
}

button {
  width: 100%;
  margin-top: 8px;
  padding: 10px 12px;
  background: #2563eb;
  color: #fff;
  border: 0;
  border-radius: 8px;
  cursor: pointer;
}

button:disabled {
  opacity: .6;
  cursor: not-allowed;
}

.note {
  font-size: 13px;
  color: #94a3b8;
  margin-top: 10px;
}

.error {
  color: #fca5a5;
  margin-top: 8px;
}

.success {
  color: #86efac;
  margin-top: 8px;
}

img {
  max-width: 100%;
  display: block;
  margin: 12px 0;
  border-radius: 8px;
}

.setup2fa, .enter2fa {
  margin-top: 20px;
}
</style>
