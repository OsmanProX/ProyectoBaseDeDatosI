<script setup lang="ts">
defineProps<{
  seccion: string
}>()

const emit = defineEmits<{
  volver: []
}>()
</script>

<template>
  <div class="denegado">
    <div class="denegado-tarjeta">
      <div class="denegado-icono">&#128274;</div>
      <h1>Acceso denegado</h1>
      <p>
        Su rol no tiene permiso para abrir <b>{{ seccion }}</b>.
        Si necesita acceso, solicítelo al administrador del sistema.
      </p>
      <button class="denegado-boton" @click="emit('volver')">Volver al inicio</button>
    </div>
  </div>
</template>

<style scoped>
.denegado {
  min-height: 70vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 30px;
}

.denegado-tarjeta {
  max-width: 420px;
  text-align: center;
  background: #fff;
  border: 1px solid #e4e8f4;
  border-radius: 16px;
  padding: 40px 32px;
  box-shadow: 0 8px 30px rgba(15, 17, 36, 0.08);
}

.denegado-icono {
  font-size: 48px;
  margin-bottom: 10px;
}

.denegado-tarjeta h1 {
  margin: 0 0 10px;
  font-size: 22px;
  color: #b1303a;
}

.denegado-tarjeta p {
  margin: 0 0 22px;
  font-size: 14px;
  color: #5a6080;
  line-height: 1.6;
}

.denegado-boton {
  padding: 10px 22px;
  border: none;
  border-radius: 10px;
  background: #3d56a8;
  color: #fff;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
}

.denegado-boton:hover {
  background: #30458c;
}
</style>
