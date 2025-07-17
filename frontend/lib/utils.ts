import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/**
 * Custom logging function with level-based filtering
 * @param level - The log level (info, error, warn, debug)
 * @param message - The message to log
 * @param data - Additional data to log
 */
export const custLog = (
  level: 'info' | 'error' | 'warn' | 'debug' = 'info',
  message: string,
  data: any | '' = '',
) => {
  const currentLogLevel = parseInt(process.env.NEXT_PUBLIC_LOG_LEVEL || '0', 10)

  enum LogLevel {
    none = 0,
    info = 1,
    error = 2,
    warn = 3,
    debug = 4,
  }

  const logLevelValue = LogLevel[level]

  if (logLevelValue <= currentLogLevel) {
    switch (level) {
      case 'info':
        console.log('[INFO]', message, data)
        break
      case 'error':
        console.error('[ERROR]', message, data)
        break
      case 'warn':
        console.warn('[WARN]', message, data)
        break
      case 'debug':
        console.debug('[DEBUG]', message, data)
        break
    }
  }
}
