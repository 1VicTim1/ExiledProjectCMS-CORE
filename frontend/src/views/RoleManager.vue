<template>
  <div class="container py-4">
    <div class="d-flex align-items-center mb-4">
      <i class="bi bi-shield-lock display-5 text-primary me-3"></i>
      <h2 class="fw-bold mb-0">Управление ролями</h2>
      <button class="btn btn-success ms-auto" @click="createRole"><i class="bi bi-plus-lg"></i> Новая роль</button>
    </div>
    <div class="table-responsive">
      <table class="table table-hover align-middle">
        <thead>
        <tr>
          <th>#</th>
          <th>Название</th>
          <th>Требовать 2FA</th>
          <th>Разрешения</th>
          <th></th>
        </tr>
        </thead>
        <tbody>
        <tr v-for="role in roles" :key="role.id">
          <td>{{ role.id }}</td>
          <td><input v-model="role.name" class="form-control form-control-sm" @blur="saveRole(role)"></td>
          <td>
            <div class="form-check form-switch">
              <input v-model="role.force2fa" class="form-check-input" type="checkbox" @change="saveRole(role)">
            </div>
          </td>
          <td>
            <div class="d-flex flex-wrap gap-1">
                <span v-for="perm in allPermissions" :key="perm" class="badge bg-secondary">
                  <input v-model="role.permissions" :value="perm" type="checkbox" @change="saveRole(role)"> {{ perm }}
                </span>
            </div>
          </td>
          <td>
            <button class="btn btn-sm btn-danger" @click="deleteRole(role.id)"><i class="bi bi-trash"></i></button>
          </td>
        </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script lang="ts" setup>
import {ref} from 'vue'

interface Role {
  id: number,
  name: string,
  force2fa: boolean,
  permissions: string[]
}

const API = import.meta.env.VITE_API_BASE_URL || ''

const roles = ref<Role[]>([
  {
    id: 1,
    name: 'Админ',
    force2fa: true,
    permissions: ['force_password_change', 'force_2fa_bind', 'edit_ui_permissions']
  },
  {id: 2, name: 'Пользователь', force2fa: false, permissions: []}
])
const allPermissions = ref<string[]>(['force_password_change', 'force_2fa_bind', 'edit_ui_permissions'])

function createRole() {
  const id = Math.max(0, ...roles.value.map(r => r.id)) + 1
  const role: Role = {id, name: '', force2fa: false, permissions: []}
  roles.value.push(role)
  // Try to persist new role
  saveRole(role)
}

async function saveRole(role: Role) {
  try {
    const method = roles.value.some(r => r.id === role.id) ? 'PUT' : 'POST'
    await fetch(`${API}/api/roles${method === 'PUT' ? '/' + role.id : ''}`,
        {method, headers: {'Content-Type': 'application/json'}, body: JSON.stringify(role)})
  } catch (e) {
    console.warn('Не удалось сохранить роль (заглушка):', e)
  }
}

async function deleteRole(id: number) {
  const backup = [...roles.value]
  roles.value = roles.value.filter(r => r.id !== id)
  try {
    await fetch(`${API}/api/roles/${id}`, {method: 'DELETE'})
  } catch (e) {
    console.warn('Не удалось удалить роль (заглушка):', e)
    roles.value = backup // revert
  }
}
</script>

