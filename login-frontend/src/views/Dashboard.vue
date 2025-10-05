<template>
  <div class="container py-4">
    <div class="d-flex align-items-center mb-4">
      <i class="bi bi-speedometer2 display-5 text-primary me-3"></i>
      <h2 class="fw-bold mb-0">Панель управления</h2>
      <router-link class="btn btn-outline-secondary ms-auto" to="/profile">
        <i class="bi bi-person-circle"></i> Личный кабинет
      </router-link>
    </div>
    <div class="row g-4">
      <div class="col-md-6 col-lg-3">
        <router-link class="card h-100 text-decoration-none shadow-sm dashboard-card" to="/tokens">
          <div class="card-body text-center">
            <i class="bi bi-key display-4 text-success mb-2"></i>
            <h5 class="card-title">API Токены</h5>
            <p class="card-text text-muted">Управление вашими API токенами и их разрешениями.</p>
          </div>
        </router-link>
      </div>
      <div class="col-md-6 col-lg-3">
        <router-link class="card h-100 text-decoration-none shadow-sm dashboard-card" to="/logs">
          <div class="card-body text-center">
            <i class="bi bi-journal-text display-4 text-info mb-2"></i>
            <h5 class="card-title">Логи действий</h5>
            <p class="card-text text-muted">Просмотр и фильтрация логов действий пользователей и токенов.</p>
          </div>
        </router-link>
      </div>
      <div class="col-md-6 col-lg-3">
        <router-link class="card h-100 text-decoration-none shadow-sm dashboard-card" to="/users">
          <div class="card-body text-center">
            <i class="bi bi-people display-4 text-warning mb-2"></i>
            <h5 class="card-title">Пользователи</h5>
            <p class="card-text text-muted">Список пользователей, 2FA, IP, регистрация, вход.</p>
          </div>
        </router-link>
      </div>
      <div v-if="hasPermission('edit_pages')" class="col-md-6 col-lg-3">
        <router-link class="card h-100 text-decoration-none shadow-sm dashboard-card" to="/page-editor">
          <div class="card-body text-center">
            <i class="bi bi-pencil-square display-4 text-primary mb-2"></i>
            <h5 class="card-title">Редактор страниц</h5>
            <p class="card-text text-muted">Создание и редактирование html-страниц для админки.</p>
          </div>
        </router-link>
      </div>
      <div class="col-md-6 col-lg-3">
        <router-link class="card h-100 text-decoration-none shadow-sm dashboard-card" to="/roles">
          <div class="card-body text-center">
            <i class="bi bi-shield-lock display-4 text-danger mb-2"></i>
            <h5 class="card-title">Роли и разрешения</h5>
            <p class="card-text text-muted">Управление ролями, 2FA и правами доступа.</p>
          </div>
        </router-link>
      </div>
      <div class="col-md-6 col-lg-3">
        <router-link class="card h-100 text-decoration-none shadow-sm dashboard-card" to="/messenger">
          <div class="card-body text-center">
            <i class="bi bi-chat-dots display-4 text-primary mb-2"></i>
            <h5 class="card-title">Мессенджер</h5>
            <p class="card-text text-muted">Чат между пользователями сайта.</p>
          </div>
        </router-link>
      </div>
      <div class="col-md-6 col-lg-3">
        <router-link class="card h-100 text-decoration-none shadow-sm dashboard-card" to="/notifications">
          <div class="card-body text-center">
            <i class="bi bi-bell display-4 text-warning mb-2"></i>
            <h5 class="card-title">Уведомления</h5>
            <p class="card-text text-muted">Просмотр и отправка уведомлений пользователям.</p>
          </div>
        </router-link>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import {inject} from 'vue'

const API = import.meta.env.VITE_API_BASE_URL || ''

const step = ref('login')
const loginForm = ref({login: '', password: ''})
const code = ref('')
const error = ref('')
const success = ref('')
const loading = ref(false)
const qrCode = ref('')
const secret = ref('')

const userPermissions = inject('userPermissions', [])

function hasPermission(perm: string) {
  return userPermissions && userPermissions.includes(perm)
}

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
      // success, redirect or show dashboard
      window.location.href = '/dashboard'
    } else if (t.Next === 'setup-2fa') {
      step.value = 'setup-2fa'
      await start2fa()
    } else if (t.Next === 'enter-2fa') {
      step.value = 'enter-2fa'
    } else {
      error.value = t.Message || 'Ошибка входа'
    }
  } catch (e) {
    error.value = 'Ошибка сети'
  } finally {
    loading.value = false
  }
}

async function start2fa() {
  try {
    const r = await fetch(`${API}/api/web/2fa/start`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({login: loginForm.value.login})
    })
    const t = await r.json()
    qrCode.value = t.QrCodeDataUrl
    secret.value = t.Secret
  } catch {
  }
}

async function verify2fa() {
  error.value = ''
  loading.value = true
  try {
    const r = await fetch(`${API}/api/web/2fa/verify`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({login: loginForm.value.login, code: code.value})
    })
    const t = await r.json().catch(() => ({}))
    if (r.status === 200) {
      success.value = t.Message || '2FA успешно'
      setTimeout(() => window.location.href = '/dashboard', 1000)
    } else {
      error.value = t.Message || 'Ошибка 2FA'
    }
  } catch (e) {
    error.value = 'Ошибка сети'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.dashboard-card {
  transition: transform 0.15s;
}

.dashboard-card:hover {
  transform: translateY(-4px) scale(1.03);
  box-shadow: 0 0.5rem 1.5rem rgba(111, 66, 193, 0.12);
}

.login-bg {
  background: linear-gradient(135deg, #6f42c1 0%, #007bff 100%);
}

.login-card {
  min-width: 340px;
  max-width: 400px;
  border-radius: 1.2rem;
}
</style>
<template>
  <div class="login-bg d-flex align-items-center justify-content-center min-vh-100">
    <div class="card shadow-lg p-4 login-card">
      <div class="text-center mb-4">
        <i class="bi bi-shield-lock-fill display-3 text-primary"></i>
        <h2 class="fw-bold mt-2">Вход в Exiled CMS</h2>
        <p class="text-muted">Добро пожаловать! Пожалуйста, авторизуйтесь для доступа к системе.</p>
      </div>
      <form v-if="step==='login'" @submit.prevent="login">
        <div class="mb-3">
          <label class="form-label">Логин</label>
          <div class="input-group">
            <span class="input-group-text"><i class="bi bi-person"></i></span>
            <input v-model="loginForm.login" autocomplete="username" class="form-control" required>
          </div>
        </div>
        <div class="mb-3">
          <label class="form-label">Пароль</label>
          <div class="input-group">
            <span class="input-group-text"><i class="bi bi-key"></i></span>
            <input v-model="loginForm.password" autocomplete="current-password" class="form-control" required
                   type="password">
          </div>
        </div>
        <button :disabled="loading" class="btn btn-primary w-100">
          <i class="bi bi-box-arrow-in-right me-2"></i>Войти
        </button>
        <div v-if="error" class="alert alert-danger mt-3">{{ error }}</div>
      </form>
      <div v-else-if="step==='setup-2fa'">
        <h5 class="mb-3">Привязка 2FA</h5>
        <div v-if="qrCode" class="text-center mb-2">
          <img :src="qrCode" alt="QR-код 2FA" class="mb-2" style="max-width: 180px;">
          <div class="small text-muted">Секрет: {{ secret }}</div>
        </div>
        <div class="alert alert-info">Отсканируйте QR-код в Google Authenticator, затем введите 6-значный код ниже.
        </div>
        <form @submit.prevent="verify2fa">
          <div class="input-group mb-2">
            <span class="input-group-text"><i class="bi bi-shield-lock"></i></span>
            <input v-model="code" class="form-control" maxlength="6" placeholder="123456" required>
          </div>
          <button :disabled="loading" class="btn btn-success w-100">Подтвердить</button>
        </form>
        <div v-if="error" class="alert alert-danger mt-3">{{ error }}</div>
        <div v-if="success" class="alert alert-success mt-3">{{ success }}</div>
      </div>
      <div v-else-if="step==='enter-2fa'">
        <h5 class="mb-3">Введите код 2FA</h5>
        <form @submit.prevent="verify2fa">
          <div class="input-group mb-2">
            <span class="input-group-text"><i class="bi bi-shield-lock"></i></span>
            <input v-model="code" class="form-control" maxlength="6" placeholder="123456" required>
          </div>
          <button :disabled="loading" class="btn btn-primary w-100">Войти</button>
        </form>
        <div v-if="error" class="alert alert-danger mt-3">{{ error }}</div>
        <div v-if="success" class="alert alert-success mt-3">{{ success }}</div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
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
      // success, redirect or show dashboard
      window.location.href = '/dashboard'
    } else if (t.Next === 'setup-2fa') {
      step.value = 'setup-2fa'
      await start2fa()
    } else if (t.Next === 'enter-2fa') {
      step.value = 'enter-2fa'
    } else {
      error.value = t.Message || 'Ошибка входа'
    }
  } catch (e) {
    error.value = 'Ошибка сети'
  } finally {
    loading.value = false
  }
}

async function start2fa() {
  try {
    const r = await fetch(`${API}/api/web/2fa/start`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({login: loginForm.value.login})
    })
    const t = await r.json()
    qrCode.value = t.QrCodeDataUrl
    secret.value = t.Secret
  } catch {
  }
}

async function verify2fa() {
  error.value = ''
  loading.value = true
  try {
    const r = await fetch(`${API}/api/web/2fa/verify`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({login: loginForm.value.login, code: code.value})
    })
    const t = await r.json().catch(() => ({}))
    if (r.status === 200) {
      success.value = t.Message || '2FA успешно'
      setTimeout(() => window.location.href = '/dashboard', 1000)
    } else {
      error.value = t.Message || 'Ошибка 2FA'
    }
  } catch (e) {
    error.value = 'Ошибка сети'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-bg {
  background: linear-gradient(135deg, #6f42c1 0%, #007bff 100%);
}

.login-card {
  min-width: 340px;
  max-width: 400px;
  border-radius: 1.2rem;
}
</style>
