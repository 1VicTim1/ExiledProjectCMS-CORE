<template>
  <div class="container py-4">
    <div class="d-flex align-items-center mb-4">
      <i class="bi bi-journal-text display-5 text-info me-3"></i>
      <h2 class="fw-bold mb-0">Логи действий</h2>
      <button class="btn btn-danger ms-auto" @click="clearLogs">
        <i class="bi bi-trash"></i> Очистить
      </button>
    </div>
    <form class="row g-2 mb-3" @submit.prevent="fetchLogs">
      <div class="col-md-2">
        <input v-model="filters.userId" class="form-control" placeholder="User ID" type="number">
      </div>
      <div class="col-md-2">
        <input v-model="filters.action" class="form-control" placeholder="Действие">
      </div>
      <div class="col-md-2">
        <input v-model="filters.apiTokenId" class="form-control" placeholder="Token ID" type="number">
      </div>
      <div class="col-md-2">
        <input v-model="filters.details" class="form-control" placeholder="Детали">
      </div>
      <div class="col-md-2">
        <input v-model="filters.ip" class="form-control" placeholder="IP">
      </div>
      <div class="col-md-2">
        <button class="btn btn-outline-primary w-100"><i class="bi bi-search"></i> Фильтр</button>
      </div>
    </form>
    <div class="table-responsive">
      <table class="table table-striped table-hover align-middle">
        <thead>
        <tr>
          <th>#</th>
          <th>Пользователь</th>
          <th>Токен</th>
          <th>Действие</th>
          <th>Детали</th>
          <th>IP</th>
          <th>Время</th>
        </tr>
        </thead>
        <tbody>
        <tr v-for="l in logs" :key="l.Id">
          <td>{{ l.Id }}</td>
          <td>{{ l.UserId ?? '—' }}</td>
          <td>{{ l.ApiTokenId ?? '—' }}</td>
          <td><span class="badge bg-info text-dark">{{ l.Action }}</span></td>
          <td>{{ l.Details }}</td>
          <td>{{ l.Ip }}</td>
          <td>{{ formatDate(l.CreatedAt) }}</td>
        </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script lang="ts" setup>
import {onMounted, ref} from 'vue'

const API = import.meta.env.VITE_API_BASE_URL || ''
const logs = ref<any[]>([])
const filters = ref({userId: '', action: '', apiTokenId: '', details: '', ip: ''})

function formatDate(d: string) {
  return new Date(d).toLocaleString('ru')
}

async function fetchLogs() {
  try {
    const params = new URLSearchParams()
    Object.entries(filters.value).forEach(([k, v]) => {
      if (v) params.append(k, v as string)
    })
    const r = await fetch(`${API}/api/audit-logs?${params}`)
    logs.value = await r.json()
  } catch (e) {
    console.warn('Не удалось загрузить логи:', e)
    logs.value = []
  }
}

onMounted(fetchLogs)

async function clearLogs() {
  if (!confirm('Очистить логи?')) return
  await fetch(`${API}/api/audit-logs`, {method: 'DELETE'})
  fetchLogs()
}
</script>

