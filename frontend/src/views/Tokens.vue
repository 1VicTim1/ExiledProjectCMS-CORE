<template>
  <div class="container py-4">
    <div class="d-flex align-items-center mb-4">
      <i class="bi bi-key display-5 text-success me-3"></i>
      <h2 class="fw-bold mb-0">API Токены</h2>
      <button class="btn btn-primary ms-auto" @click="showCreate = true">
        <i class="bi bi-plus-lg"></i> Новый токен
      </button>
    </div>
    <div class="table-responsive">
      <table class="table table-hover align-middle">
        <thead>
        <tr>
          <th>#</th>
          <th>Имя</th>
          <th>Создан</th>
          <th>Истекает</th>
          <th>Разрешения</th>
          <th></th>
        </tr>
        </thead>
        <tbody>
        <tr v-for="t in tokens" :key="t.Id">
          <td>{{ t.Id }}</td>
          <td>{{ t.Name }}</td>
          <td>{{ formatDate(t.CreatedAt) }}</td>
          <td>{{ t.ExpiresAt ? formatDate(t.ExpiresAt) : '—' }}</td>
          <td>
            <span v-for="pid in t.Permissions" :key="pid" class="badge bg-secondary me-1">{{ permName(pid) }}</span>
          </td>
          <td>
            <button class="btn btn-sm btn-danger" @click="removeToken(t.Id)"><i class="bi bi-trash"></i></button>
          </td>
        </tr>
        </tbody>
      </table>
    </div>
    <!-- Модальное окно создания токена -->
    <div v-if="showCreate" class="modal-backdrop fade show"></div>
    <div v-if="showCreate" class="modal d-block" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title"><i class="bi bi-key"></i> Новый токен</h5>
            <button class="btn-close" type="button" @click="showCreate = false"></button>
          </div>
          <div class="modal-body">
            <div class="mb-3">
              <label class="form-label">Имя токена</label>
              <input v-model="newToken.name" class="form-control" required>
            </div>
            <div class="mb-3">
              <label class="form-label">Истекает (опционально)</label>
              <input v-model="newToken.expiresAt" class="form-control" type="date">
            </div>
            <div class="mb-3">
              <label class="form-label">Разрешения</label>
              <div class="d-flex flex-wrap gap-2">
                <div v-for="p in allPerms" :key="p.Id" class="form-check">
                  <input :id="'perm'+p.Id" v-model="newToken.permissions" :value="p.Id" class="form-check-input"
                         type="checkbox">
                  <label :for="'perm'+p.Id" class="form-check-label">{{ p.Name }}</label>
                </div>
              </div>
            </div>
            <div v-if="error" class="alert alert-danger">{{ error }}</div>
            <div v-if="createdToken" class="alert alert-success">
              <div>Токен создан!</div>
              <div><b>Секрет:</b> <code>{{ createdToken }}</code></div>
              <div class="small text-muted">Сохраните этот токен — он не будет показан повторно.</div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showCreate = false">Отмена</button>
            <button :disabled="loading" class="btn btn-primary" @click="createToken">Создать</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import {onMounted, ref} from 'vue'

const API = import.meta.env.VITE_API_BASE_URL || ''
const tokens = ref<any[]>([])
const allPerms = ref<any[]>([])
const showCreate = ref(false)
const newToken = ref({name: '', expiresAt: '', permissions: [] as number[]})
const error = ref('')
const loading = ref(false)
const createdToken = ref('')

function formatDate(d: string) {
  return new Date(d).toLocaleString('ru')
}

function permName(id: number) {
  const p = allPerms.value.find(x => x.Id === id)
  return p ? p.Name : id
}

async function fetchTokens() {
  try {
    const r = await fetch(`${API}/api/tokens`)
    tokens.value = await r.json()
  } catch (e) {
    console.warn('Не удалось загрузить токены:', e)
    tokens.value = []
  }
}

async function fetchPerms() {
  try {
    const r = await fetch(`${API}/api/permissions`)
    allPerms.value = await r.json()
  } catch (e) {
    console.warn('Не удалось загрузить разрешения:', e)
    allPerms.value = []
  }
}

onMounted(() => {
  fetchTokens()
  fetchPerms()
})

async function createToken() {
  error.value = ''
  loading.value = true
  createdToken.value = ''
  try {
    const r = await fetch(`${API}/api/tokens`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        name: newToken.value.name,
        expiresAt: newToken.value.expiresAt || null,
        permissionIds: newToken.value.permissions
      })
    })
    const t = await r.json()
    if (r.ok) {
      createdToken.value = t.Token
      await fetchTokens()
      newToken.value = {name: '', expiresAt: '', permissions: []}
    } else {
      error.value = t.Message || 'Ошибка создания токена'
    }
  } catch (e: any) {
    error.value = e?.message || 'Ошибка сети при создании токена'
  } finally {
    loading.value = false
  }
}

async function removeToken(id: number) {
  if (!confirm('Удалить токен?')) return
  try {
    await fetch(`${API}/api/tokens/${id}`, {method: 'DELETE'})
    await fetchTokens()
  } catch (e) {
    console.warn('Не удалось удалить токен:', e)
  }
}
</script>

<style scoped>
.modal-backdrop {
  z-index: 1040;
}

.modal {
  z-index: 1050;
}
</style>
