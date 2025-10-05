<template>
  <div class="container py-4">
    <div class="d-flex align-items-center mb-4">
      <i class="bi bi-chat-dots display-5 text-primary me-3"></i>
      <h2 class="fw-bold mb-0">Мессенджер</h2>
    </div>
    <div v-if="notifications.length" class="alert alert-info mb-3">
      <i class="bi bi-bell"></i> Новые уведомления: {{ notifications.length }}
      <router-link class="ms-2" to="/notifications">Посмотреть</router-link>
    </div>
    <div class="row">
      <div class="col-md-4">
        <div class="list-group mb-3">
          <button v-for="u in users" :key="u.id"
                  :class="{'active': u.id===selectedUser?.id}"
                  class="list-group-item list-group-item-action d-flex justify-content-between align-items-center" @click="selectUser(u)">
            <span>{{ u.name }}</span>
            <span v-if="u.unread" class="badge bg-danger">{{ u.unread }}</span>
          </button>
        </div>
      </div>
      <div class="col-md-8">
        <div v-if="selectedUser">
          <div class="border rounded p-3 mb-2 bg-light" style="height:340px;overflow-y:auto;">
            <div v-for="m in messages[selectedUser.id] || []" :key="m.id" :class="{'text-end': m.fromMe}">
              <div :class="['d-inline-block', 'p-2', 'mb-1', m.fromMe ? 'bg-primary text-white' : 'bg-white border']"
                   style="border-radius:1rem;max-width:70%;">
                <b v-if="!m.fromMe">{{ selectedUser.name }}:</b> {{ m.text }}
                <span class="small text-muted ms-2">{{ formatTime(m.time) }}</span>
              </div>
            </div>
          </div>
          <form class="d-flex gap-2" @submit.prevent="sendMessage">
            <input v-model="newMessage" class="form-control" placeholder="Сообщение...">
            <button class="btn btn-primary"><i class="bi bi-send"></i></button>
          </form>
        </div>
        <div v-else class="text-muted">Выберите пользователя для переписки.</div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import {ref} from 'vue'

const users = ref([
  {id: 2, name: 'Иван', unread: 1},
  {id: 3, name: 'Мария', unread: 0},
  {id: 4, name: 'Тест', unread: 0}
])
const selectedUser = ref<any | null>(null)
const messages = ref<Record<number, any[]>>({
  2: [
    {id: 1, text: 'Привет!', fromMe: false, time: Date.now() - 60000},
    {id: 2, text: 'Добрый день!', fromMe: true, time: Date.now() - 59000}
  ]
})
const newMessage = ref('')
const notifications = ref([
  {id: 1, title: 'Вам пришло новое сообщение', time: Date.now() - 60000}
])

function selectUser(u: any) {
  selectedUser.value = u
  u.unread = 0
}

function sendMessage() {
  if (!selectedUser.value || !newMessage.value.trim()) return
  const arr = messages.value[selectedUser.value.id] = messages.value[selectedUser.value.id] || []
  arr.push({id: Date.now(), text: newMessage.value, fromMe: true, time: Date.now()})
  newMessage.value = ''
}

function formatTime(t: number) {
  return new Date(t).toLocaleTimeString('ru-RU', {hour: '2-digit', minute: '2-digit'})
}
</script>
