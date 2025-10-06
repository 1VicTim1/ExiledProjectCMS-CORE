<template>
  <div class="container py-4">
    <div class="row justify-content-center">
      <div class="col-md-7 col-lg-6">
        <div class="card shadow p-4">
          <div class="d-flex align-items-center mb-3">
            <img :src="user.avatarUrl || defaultAvatar" alt="avatar"
                 class="rounded-circle me-3" style="width:64px;height:64px;object-fit:cover;">
            <div>
              <h3 class="fw-bold mb-0">Личный кабинет</h3>
              <div class="text-muted">Добро пожаловать, {{ user.Login }}</div>
            </div>
            <button class="btn btn-sm btn-outline-secondary ms-auto" @click="showAvatarModal=true"><i
                class="bi bi-image"></i></button>
          </div>
          <ul class="list-group list-group-flush mb-3">
            <li class="list-group-item"><b>Почта:</b> {{ user.Email || '—' }}</li>
            <li class="list-group-item"><b>2FA:</b>
              <span v-if="user.TwoFactorEnabled" class="badge bg-success"><i
                  class="bi bi-shield-lock"></i> Включена</span>
              <span v-else class="badge bg-secondary">Отключена</span>
            </li>
            <li class="list-group-item"><b>Дата регистрации:</b> {{ formatDate(user.RegisteredAt) }}</li>
            <li class="list-group-item"><b>Последний вход:</b> {{ formatDate(user.LastLoginAt) }}</li>
          </ul>
          <div v-if="!user.TwoFactorEnabled" class="alert alert-warning d-flex align-items-center gap-2">
            <i class="bi bi-exclamation-triangle"></i>
            <span>2FA не привязана. <button class="btn btn-sm btn-warning ms-2" @click="change2fa"><i
                class="bi bi-shield-lock"></i> Привязать</button></span>
          </div>
          <div class="d-flex gap-2 mb-2">
            <button class="btn btn-outline-primary" @click="showPasswordModal=true"><i class="bi bi-key"></i> Сменить
              пароль
            </button>
            <button class="btn btn-outline-secondary" @click="change2fa"><i class="bi bi-shield-lock"></i> Управление
              2FA
            </button>
            <button class="btn btn-outline-dark" @click="toggleTheme"><i class="bi bi-moon"></i> Тема</button>
            <button class="btn btn-outline-info" @click="showNotifications"><i class="bi bi-bell"></i> Уведомления
            </button>
            <router-link v-if="hasPermission('admin_panel')" class="btn btn-outline-danger" to="/dashboard"><i
                class="bi bi-shield-lock"></i> Админ-панель
            </router-link>
            <router-link v-if="hasPermission('edit_pages')" class="btn btn-outline-primary" to="/page-editor"><i
                class="bi bi-pencil-square"></i> Редактор страниц
            </router-link>
            <router-link class="btn btn-outline-success" to="/profile"><i class="bi bi-person-circle"></i> Профиль
            </router-link>
          </div>
        </div>
        <!-- Карточка уведомлений -->
        <div class="card mt-4">
          <div class="card-header d-flex align-items-center">
            <i class="bi bi-bell me-2"></i>
            <b>Уведомления</b>
            <router-link class="btn btn-sm btn-outline-primary ms-auto" to="/notifications">Все уведомления
            </router-link>
          </div>
          <div class="card-body p-2">
            <ul class="list-group mb-0">
              <li v-for="n in notifications.slice(0,3)" :key="n.id" class="list-group-item d-flex align-items-center">
                <i class="bi bi-info-circle me-2 text-info"></i>
                <div>
                  <b>{{ n.title }}</b>
                  <div class="small text-muted">{{ formatDate(n.time) }}</div>
                </div>
              </li>
              <li v-if="notifications.length===0" class="list-group-item text-muted">Нет новых уведомлений</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    <!-- Модальное окно смены пароля -->
    <div v-if="showPasswordModal" class="modal fade show d-block" style="background:rgba(0,0,0,0.3);" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header"><h5 class="modal-title">Смена пароля</h5>
            <button class="btn-close" type="button" @click="showPasswordModal=false"></button>
          </div>
          <div class="modal-body">
            <input v-model="passwordForm.old" class="form-control mb-2" placeholder="Старый пароль" type="password">
            <input v-model="passwordForm.new1" class="form-control mb-2" placeholder="Новый пароль" type="password">
            <input v-model="passwordForm.new2" class="form-control mb-2" placeholder="Повторите новый пароль"
                   type="password">
            <div v-if="passwordError" class="alert alert-danger">{{ passwordError }}</div>
            <div v-if="passwordSuccess" class="alert alert-success">{{ passwordSuccess }}</div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showPasswordModal=false">Отмена</button>
            <button class="btn btn-primary" @click="submitPassword">Сменить</button>
          </div>
        </div>
      </div>
    </div>
    <!-- Модальное окно смены аватара -->
    <div v-if="showAvatarModal" class="modal fade show d-block" style="background:rgba(0,0,0,0.3);" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header"><h5 class="modal-title">Сменить аватар</h5>
            <button class="btn-close" type="button" @click="showAvatarModal=false"></button>
          </div>
          <div class="modal-body">
            <input class="form-control mb-2" type="file" @change="onAvatarChange">
            <div v-if="avatarPreview"><img :src="avatarPreview" class="rounded-circle"
                                           style="width:96px;height:96px;object-fit:cover;"></div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showAvatarModal=false">Отмена</button>
            <button class="btn btn-primary" @click="saveAvatar">Сохранить</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import {inject, onMounted, ref} from 'vue'
import {useRouter} from 'vue-router'

const API = import.meta.env.VITE_API_BASE_URL || ''
const router = useRouter()
const user = ref<any>({})
const defaultAvatar = '/default-avatar.png'
const showPasswordModal = ref(false)
const showAvatarModal = ref(false)
const avatarPreview = ref<string | null>(null)
const passwordForm = ref({old: '', new1: '', new2: ''})
const passwordError = ref('')
const passwordSuccess = ref('')
const notifications = ref([
  {id: 1, title: 'Важное обновление', time: Date.now() - 3600000},
  {id: 2, title: 'Добро пожаловать!', time: Date.now() - 7200000}
])
const userPermissions = inject('userPermissions', ref<string[]>(['admin_panel', 'edit_pages']))

function hasPermission(perm: string) {
  return userPermissions.value.includes(perm)
}

function formatDate(d: string) {
  if (!d) return '—'
  return new Date(d).toLocaleString('ru')
}

async function fetchProfile() {
  const r = await fetch(`${API}/api/profile?userId=1`)
  user.value = await r.json()
}

onMounted(fetchProfile)

function change2fa() {
  // Направим пользователя в раздел 2FA на дашборде (минимально инвазивно)
  router.push('/dashboard')
}

function toggleTheme() {
  document.body.classList.toggle('dark-theme')
}

function showNotifications() {
  router.push('/notifications')
}

function onAvatarChange(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (file) {
    const reader = new FileReader()
    reader.onload = ev => avatarPreview.value = ev.target?.result as string
    reader.readAsDataURL(file)
  }
}

function saveAvatar() {
  user.value.avatarUrl = avatarPreview.value
  showAvatarModal.value = false
}

async function submitPassword() {
  passwordError.value = ''
  passwordSuccess.value = ''
  if (passwordForm.value.new1 !== passwordForm.value.new2) {
    passwordError.value = 'Пароли не совпадают'
    return
  }
  try {
    const r = await fetch(`${API}/api/profile/change-password`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({old: passwordForm.value.old, password: passwordForm.value.new1, userId: 1})
    })
    if (!r.ok) throw new Error('Ошибка смены пароля')
    passwordSuccess.value = 'Пароль успешно изменён'
    setTimeout(() => showPasswordModal.value = false, 1200)
  } catch (e: any) {
    passwordError.value = e?.message || 'Не удалось изменить пароль'
  }
}
</script>

<style scoped>
.dark-theme {
  background: #181a1b !important;
  color: #f8f9fa !important;
}
</style>
