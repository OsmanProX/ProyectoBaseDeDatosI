const token = (name) => `rgb(var(--${name}) / <alpha-value>)`
export default {
  content: ['./index.html', './src/**/*.{vue,ts}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: Object.fromEntries(
        [
          'primary',
          'primary-dark',
          'accent',
          'background',
          'surface',
          'border',
          'text',
          'muted',
          'success',
          'warning',
          'danger',
          'info',
        ].map((name) => [name, token(name)]),
      ),
      fontFamily: { sans: ['Inter', 'sans-serif'] },
      borderRadius: { xl: '12px' },
      boxShadow: { soft: '0 4px 24px rgb(15 23 42 / 0.04)' },
    },
  },
  plugins: [],
}
