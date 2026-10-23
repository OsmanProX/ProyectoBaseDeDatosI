<script setup lang="ts">
import ConfirmDialog from '@/shared/components/ConfirmDialog.vue'
import Toast from '@/shared/components/Toast.vue'
import { useThemeStore } from '@/app/providers/theme.store'

// El tema (claro/oscuro) se aplica en toda la app, también en el login
useThemeStore()
</script>
<template><RouterView /><ConfirmDialog /><Toast /></template>
