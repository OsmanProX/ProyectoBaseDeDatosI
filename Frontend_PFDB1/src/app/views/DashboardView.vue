<script setup lang="ts">
import { GraduationCap, Layers3 } from 'lucide-vue-next'
</script>

<template>
  <section>
    <div class="mb-7">
      <p class="eyebrow mb-2">Proyecto de clase</p>
      <h1 class="text-3xl font-semibold">Frontend administrativo</h1>
      <p class="mt-3 max-w-2xl text-sm leading-6 text-muted">
        Esta plantilla contiene la estructura visual y técnica desde la que construiremos cada
        módulo paso a paso.
      </p>
    </div>

    <div class="relative overflow-hidden rounded-2xl bg-[#25235b] p-7 text-white sm:p-10">
      <div
        class="absolute -right-20 -top-40 h-96 w-96 rounded-full border-[45px] border-white/[0.035]"
      />
      <div class="relative grid items-center gap-8 md:grid-cols-[1fr_auto]">
        <div>
          <span
            class="mb-4 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/5 px-3 py-1.5 text-[10px] font-medium uppercase tracking-widest text-indigo-100"
          >
            <span class="h-1.5 w-1.5 rounded-full bg-teal-300" />UMG · LA FLORIDA
          </span>
          <h2 class="max-w-xl text-2xl font-semibold leading-snug sm:text-3xl">Plantilla.</h2>
          <p class="mt-4 max-w-lg text-sm leading-6 text-indigo-100/80">
            Plantilla hecha por Morataya.
          </p>
        </div>
        <div
          class="hidden h-40 w-40 items-center justify-center rounded-[2rem] border border-white/15 bg-white/5 md:flex"
        >
          <GraduationCap class="h-20 w-20 text-indigo-100" stroke-width="1" />
        </div>
      </div>
    </div>

    <div class="mt-8 grid gap-4 md:grid-cols-2">
      <article class="panel p-6">
        <span
          class="flex h-11 w-11 items-center justify-center rounded-xl bg-primary/10 text-primary"
        >
          <Layers3 class="h-5 w-5" />
        </span>
        <h2 class="mt-5 font-semibold">Textos</h2>
        <p class="mt-2 text-sm leading-6 text-muted">Configuración para tarjetas.</p>
      </article>
    </div>
  </section>
</template>
