<template>
  <div class="container py-4">
    <div class="d-flex align-items-center mb-4">
      <i class="bi bi-people display-5 text-warning me-3"></i>
      <h2 class="fw-bold mb-0">Пользователи</h2>
    </div>
    <div class="mb-2 d-flex align-items-center gap-2">
      <button v-if="hasPermission('send_notifications')" class="btn btn-outline-info btn-sm" @click="openNotifyModal">
        <i class="bi bi-bell"></i> Отправить уведомление выбранным
      </button>
      <div class="form-check">
        <input v-model="selectAll" class="form-check-input" type="checkbox" @change="toggleSelectAll">
        <label class="form-check-label">Выбрать всех</label>
      </div>
    </div>
    <div class="table-responsive">
      <table class="table table-hover align-middle">
        <thead>
        <tr>
          <th v-if="hasPermission('send_notifications')"></th>
          <th>#</th>
          <th>Логин/Почта</th>
          <th>2FA</th>
          <th>Последний IP</th>
          <th>Дата регистрации</th>
          <th>Последний вход</th>
          <th v-if="hasPermission('force_password_change') || hasPermission('force_2fa_bind')">Действия</th>
        </tr>
        </thead>
        <tbody>
        <tr v-for="u in users" :key="u.Id">
          <td v-if="hasPermission('send_notifications')">
            <input v-model="selectedIds" :value="u.Id" type="checkbox">
          </td>
          <td>{{ u.Id }}</td>
          <td>{{ u.Login || u.Email }}</td>
          <td>
            <span v-if="u.TwoFactorEnabled" class="badge bg-success"><i class="bi bi-shield-lock"></i> Да</span>
            <span v-else class="badge bg-secondary">Нет</span>
          </td>
          <td>{{ u.LastIp || '—' }}</td>
          <td>{{ formatDate(u.RegisteredAt) }}</td>
          <td>{{ formatDate(u.LastLoginAt) }}</td>
          <td v-if="hasPermission('force_password_change') || hasPermission('force_2fa_bind')">
            <button v-if="hasPermission('force_password_change')" class="btn btn-sm btn-warning me-1"
                    @click="forcePasswordChange(u.Id)"><i class="bi bi-key"></i></button>
            <button v-if="hasPermission('force_2fa_bind')" class="btn btn-sm btn-info" @click="force2faBind(u.Id)"><i
                class="bi bi-shield-lock"></i></button>
          </td>
        </tr>
        </tbody>
      </table>
    </div>

    <!-- Модальное окно отправки уведомления -->
    <div v-if="showNotifyModal" class="modal fade show d-block" style="background:rgba(0,0,0,0.3);" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header"><h5 class="modal-title">Отправить уведомление</h5>
            <button class="btn-close" type="button" @click="showNotifyModal=false"></button>
          </div>
          <div class="modal-body">
            <input v-model="notifyForm.title" class="form-control mb-2" placeholder="Заголовок">
            <textarea v-model="notifyForm.text" class="form-control mb-2" placeholder="Текст уведомления"></textarea>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showNotifyModal=false">Отмена</button>
            <button class="btn btn-primary" @click="sendNotify">Отправить</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import {inject, onMounted, ref} from 'vue'

const API = import.meta.env.VITE_API_BASE_URL || ''
const users = ref<any[]>([])
// Глобальные разрешения пользователя (можно заменить на Pinia/store)
const userPermissions = inject('userPermissions', ref<string[]>(['force_password_change', 'force_2fa_bind']))

function hasPermission(perm: string) {
  return userPermissions.value.includes(perm)
}

function formatDate(d: string) {
  if (!d) return '—'
  return new Date(d).toLocaleString('ru')
}

async function fetchUsers() {
  const r = await fetch(`${API}/api/users?userId=1`)
  users.value = await r.json()
}

onMounted(fetchUsers)

async function forcePasswordChange(userId: number) {
  if (!confirm('Заставить пользователя сменить пароль при следующем входе?')) return
  await fetch(`${API}/api/users/${userId}/force-password`, {method: 'POST'})
  alert('Пользователь будет вынужден сменить пароль при следующем входе.')
}

async function force2faBind(userId: number) {
  if (!confirm('Заставить пользователя привязать 2FA при следующем входе?')) return
  await fetch(`${API}/api/users/${userId}/force-2fa`, {method: 'POST'})
  alert('Пользователь будет вынужден привязать 2FA при следующем входе.')
}

const selectedIds = ref<number[]>([])
const selectAll = ref(false)
const showNotifyModal = ref(false)
const notifyForm = ref({title: '', text: ''})

function openNotifyModal() {
  showNotifyModal.value = true
}

function toggleSelectAll() {
  if (selectAll.value) selectedIds.value = users.value.map(u => u.Id)
  else selectedIds.value = []
}

async function sendNotify() {
  // TODO: отправить уведомление через API
  alert(`Уведомление отправлено пользователям: ${selectedIds.value.join(', ')}`)
  showNotifyModal.value = false
  notifyForm.value = {title: '', text: ''}
}
</script>
