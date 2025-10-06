<template>
  <div class="container py-4">
    <div class="d-flex align-items-center mb-4">
      <i class="bi bi-bell display-5 text-warning me-3"></i>
      <h2 class="fw-bold mb-0">Уведомления</h2>
      <button v-if="isAdmin" class="btn btn-success ms-auto" @click="showSendModal=true"><i class="bi bi-plus-lg"></i>
        Отправить
      </button>
    </div>
    <ul class="list-group mb-3">
      <li v-for="n in notifications" :key="n.id" class="list-group-item d-flex align-items-center">
        <i class="bi bi-info-circle me-2 text-info"></i>
        <div>
          <b>{{ n.title }}</b>
          <div class="small text-muted">{{ formatDate(n.time) }}</div>
          <div>{{ n.text }}</div>
        </div>
      </li>
    </ul>
    <!-- Модальное окно отправки уведомления -->
    <div v-if="showSendModal" class="modal fade show d-block" style="background:rgba(0,0,0,0.3);" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header"><h5 class="modal-title">Отправить уведомление</h5>
            <button class="btn-close" type="button" @click="showSendModal=false"></button>
          </div>
          <div class="modal-body">
            <input v-model="sendForm.title" class="form-control mb-2" placeholder="Заголовок">
            <textarea v-model="sendForm.text" class="form-control mb-2" placeholder="Текст уведомления"></textarea>
            <select v-model="sendForm.target" class="form-select mb-2">
              <option value="all">Всем пользователям</option>
              <option v-for="u in users" :key="u.id" :value="u.id">{{ u.name }}</option>
            </select>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showSendModal=false">Отмена</button>
            <button class="btn btn-primary" @click="sendNotification">Отправить</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import type {Ref} from 'vue'
import {computed, inject, ref, unref} from 'vue'

const API = import.meta.env.VITE_API_BASE_URL || ''
const userPermissions = inject<string[] | Ref<string[]>>('userPermissions', [])
const isAdmin = computed(() => {
  const perms = unref(userPermissions)
  return Array.isArray(perms) && (perms.includes('admin_panel') || perms.includes('send_notifications'))
})

const notifications = ref([
  {id: 1, title: 'Важное обновление', text: 'Система будет недоступна ночью.', time: Date.now() - 3600000},
  {id: 2, title: 'Добро пожаловать!', text: 'Спасибо за регистрацию!', time: Date.now() - 7200000}
])
const users = ref([
  {id: 2, name: 'Иван'},
  {id: 3, name: 'Мария'}
])
const showSendModal = ref(false)
const sendForm = ref({title: '', text: '', target: 'all'})

function formatDate(t: number) {
  return new Date(t).toLocaleString('ru-RU')
}

async function sendNotification() {
  // Реальный вызов API с мягким фолбэком
  const payload: any = {title: sendForm.value.title, text: sendForm.value.text, target: sendForm.value.target}
  try {
    await fetch(`${API}/api/notifications`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(payload)
    })
  } catch (e) {
    console.warn('Не удалось отправить уведомление (заглушка):', e)
  }
  notifications.value.unshift({
    id: Date.now(),
    title: sendForm.value.title,
    text: sendForm.value.text,
    time: Date.now()
  })
  showSendModal.value = false
  sendForm.value = {title: '', text: '', target: 'all'}
}
</script>

