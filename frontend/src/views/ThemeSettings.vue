<template>
  <div class="theme-settings">
    <div class="page-header">
      <h1>Настройки темы</h1>
      <div class="header-actions">
        <button v-if="canManage" class="btn btn-outline" @click="resetColors">
          <i class="bi bi-arrow-clockwise"></i>
          Сбросить
        </button>
        <button :disabled="saving || !canManage" class="btn btn-primary" @click="save">
          <i class="bi bi-palette"></i>
          {{ saving ? 'Сохранение...' : 'Сохранить' }}
        </button>
      </div>
    </div>

    <div v-if="!canManage" class="alert alert-warning mb-3">
      У вас нет прав для изменения темы (нужно разрешение "manage_theme").
    </div>

    <div class="grid">
      <div v-for="(val, key) in local" :key="key" class="color-item">
        <label :for="key">{{ labels[key] || key }}</label>
        <div class="row">
          <input :id="key" v-model="local[key]" class="color-picker" type="color" @input="applyPreview"/>
          <input v-model="local[key]" class="hex-input" type="text" @change="applyPreview"/>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import {computed, inject, onMounted, reactive, ref} from 'vue';
import {getTheme, loadTheme, resetTheme, updateTheme} from '../stores/theme';

const providedPerms = inject<string[]>('userPermissions', []);
const canManage = computed(() => providedPerms?.includes?.('manage_theme'));

const labels: Record<string, string> = {
  primary: 'Основной',
  secondary: 'Вторичный',
  accent: 'Акцентный',
  error: 'Ошибка',
  warning: 'Предупреждение',
  info: 'Информация',
  success: 'Успех',
  background: 'Фон',
  surface: 'Поверхность',
};

const local = reactive<Record<string, string>>({});
const saving = ref(false);

onMounted(async () => {
  await loadTheme();
  Object.assign(local, getTheme());
  applyPreview();
});

function applyPreview() {
  // live preview without persisting
  updateTheme({...local}, false);
}

async function save() {
  if (!canManage.value) return;
  try {
    saving.value = true;
    await updateTheme({...local}, true);
    alert('Тема сохранена');
  } catch (e) {
    console.error(e);
    alert('Не удалось сохранить тему');
  } finally {
    saving.value = false;
  }
}

async function resetColors() {
  await resetTheme(true);
  Object.assign(local, getTheme());
}
</script>

<style scoped>
.theme-settings {
  padding: 24px;
  color: var(--color-text, #fff);
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.header-actions {
  display: flex;
  gap: 10px;
}

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 16px;
}

.color-item {
  background: var(--color-surface, #2D2D33);
  border: 1px solid var(--color-primary, #8B5CF6);
  padding: 12px;
  border-radius: 10px;
}

.color-item label {
  display: block;
  margin-bottom: 8px;
  font-weight: 600;
}

.row {
  display: flex;
  gap: 8px;
  align-items: center;
}

.color-picker {
  width: 46px;
  height: 40px;
  border: none;
  border-radius: 6px;
  cursor: pointer;
}

.hex-input {
  flex: 1;
  padding: 10px;
  border-radius: 6px;
  border: 1px solid #444;
  background: #3C3C45;
  color: #fff;
}

.btn {
  padding: 10px 14px;
  border-radius: 8px;
  cursor: pointer;
  border: 1px solid transparent;
  transition: all .2s;
}

.btn-primary {
  background: var(--color-primary, #8B5CF6);
  color: #fff;
}

.btn-outline {
  background: transparent;
  border-color: var(--color-primary, #8B5CF6);
  color: var(--color-primary, #8B5CF6);
}

.btn:disabled {
  opacity: .6;
  cursor: not-allowed;
}

.alert {
  padding: 12px 16px;
  border-radius: 8px;
  background: #3C3C45;
}
</style>
