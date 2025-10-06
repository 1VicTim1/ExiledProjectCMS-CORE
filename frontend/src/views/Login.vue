<template>
  <div class="login-container">
    <h1>Welcome</h1>
    <p>Please sign in to continue.</p>
    <form @submit.prevent="onSubmit">
      <label>
        Email
        <input v-model="email" placeholder="you@example.com" required type="email"/>
      </label>
      <label>
        Password
        <input v-model="password" placeholder="••••••••" required type="password"/>
      </label>
      <button :disabled="loading" type="submit">{{ loading ? 'Signing in…' : 'Sign in' }}</button>
      <p v-if="error" class="error">{{ error }}</p>
    </form>
  </div>
</template>

<script lang="ts" setup>
import {ref} from 'vue'
import {useRouter} from 'vue-router'

const router = useRouter()
const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')

async function onSubmit() {
  error.value = ''
  loading.value = true
  try {
    // Minimal non-breaking placeholder: just navigate to dashboard.
    // Replace with real API auth when backend endpoint is ready.
    await new Promise(r => setTimeout(r, 300))
    await router.push({name: 'Dashboard'})
  } catch (e: any) {
    error.value = e?.message ?? 'Failed to sign in'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-container {
  max-width: 360px;
  margin: 10vh auto;
  padding: 24px;
  border: 1px solid #eee;
  border-radius: 12px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, .06);
}

label {
  display: block;
  margin: 12px 0;
  font-size: 14px;
}

input {
  width: 100%;
  padding: 10px 12px;
  margin-top: 6px;
  border: 1px solid #ccc;
  border-radius: 8px;
}

button {
  width: 100%;
  margin-top: 12px;
  padding: 10px 12px;
  border: none;
  border-radius: 8px;
  background: #3b82f6;
  color: white;
  cursor: pointer;
}

button[disabled] {
  opacity: .7;
  cursor: default;
}

.error {
  color: #dc2626;
  margin-top: 8px;
}
</style>
