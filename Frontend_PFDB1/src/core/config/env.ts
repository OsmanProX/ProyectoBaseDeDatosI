import { z } from 'zod'
const config = z.object({ VITE_API_BASE_URL: z.string().url().default('http://localhost:5139') })
export const env = config.parse(import.meta.env)
