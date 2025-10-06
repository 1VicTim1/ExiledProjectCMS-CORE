<template>
  <router-view/>
</template>

<script lang="ts" setup>
</script>

<style>
:root {
  /* Default theme variables (overwritten at runtime) */
  --color-primary: #8B5CF6;
  --color-secondary: #7C3AED;
  --color-accent: #A78BFA;
  --color-error: #EF4444;
  --color-warning: #F59E0B;
  --color-info: #3B82F6;
  --color-success: #10B981;
  --color-background: #1F1F23;
  --color-surface: #2D2D33;
  --color-text: #FFFFFF;
}

html, body, #app {
  height: 100%;
}

body {
  background-color: var(--color-background);
  color: var(--color-text);
}

/* Global dark theme toggled on body */
body.dark-theme {
  background-color: #181a1b !important;
  color: #f8f9fa !important;
}

/* Utility classes */
.btn {
  font-family: inherit;
}
</style>
