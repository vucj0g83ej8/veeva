import { describe, expect, it } from 'vitest'
import {
  firebasePhoneAuthErrorCode,
  firebasePhoneAuthMessage,
  normalizePhoneNumber,
  normalizeVerificationCode,
} from './phoneVerification'

describe('phone verification helpers', () => {
  it('normalizes Taiwanese mobile phone numbers', () => {
    expect(normalizePhoneNumber('0912-345-678')).toBe('+886912345678')
    expect(normalizePhoneNumber('886912345678')).toBe('+886912345678')
  })

  it('keeps only the first six-digit verification code', () => {
    expect(normalizeVerificationCode('02543322')).toBe('025433')
  })

  it('records Firebase error codes and gives actionable messages', () => {
    const error = { code: 'auth/network-request-failed' }
    expect(firebasePhoneAuthErrorCode(error)).toBe('auth/network-request-failed')
    expect(firebasePhoneAuthMessage(error)).toContain('網路連線不穩定')
  })

  it('labels client-side timeouts for diagnostics', () => {
    const error = new Error('簡訊發送逾時，請重新發送')
    expect(firebasePhoneAuthErrorCode(error)).toBe('client/timeout')
  })
})
