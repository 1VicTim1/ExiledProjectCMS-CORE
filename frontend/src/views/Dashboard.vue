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
import type {Ref} from 'vue'
import {inject, unref} from 'vue'

const userPermissions = inject<string[] | Ref<string[]>>('userPermissions', [])

function hasPermission(perm: string) {
  const perms = unref(userPermissions)
  return Array.isArray(perms) && perms.includes(perm)
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
</style>
