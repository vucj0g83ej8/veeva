import {
  RecaptchaVerifier,
  signInWithPhoneNumber,
  type ConfirmationResult,
} from 'firebase/auth'
import {
  doc,
  increment,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
} from 'firebase/firestore'
import { firebaseAuth, firestore } from './firebase'

let recaptchaVerifier: RecaptchaVerifier | undefined
let confirmationResult: ConfirmationResult | undefined
const smsSendCooldownMs = 60_000
const smsVerificationCodeLength = 6

export interface ConfirmedPhoneVerification {
  phoneNumber: string
  firebasePhoneUid: string
}

export function normalizePhoneNumber(input: string) {
  const trimmed = input.trim()
  if (!trimmed) {
    throw new Error('請輸入手機號碼')
  }

  const international = trimmed.replace(/[^\d+]/g, '')
  if (international.startsWith('+')) {
    if (!/^\+\d{8,15}$/.test(international)) {
      throw new Error('請輸入正確的國際手機格式，例如 +886912345678')
    }
    return international
  }

  const digits = trimmed.replace(/\D/g, '')
  if (/^09\d{8}$/.test(digits)) {
    return `+886${digits.slice(1)}`
  }
  if (/^8869\d{8}$/.test(digits)) {
    return `+${digits}`
  }

  throw new Error('請輸入台灣手機號碼，例如 0912345678')
}

export function normalizeVerificationCode(input: string) {
  const firstSixDigitCode = input.match(/\d{6}/)?.[0]
  if (firstSixDigitCode) return firstSixDigitCode
  return input.replace(/\D/g, '').slice(0, smsVerificationCodeLength)
}

export async function sendPhoneVerificationCode(
  phoneNumber: string,
  memberId?: string,
) {
  const normalizedPhoneNumber = normalizePhoneNumber(phoneNumber)
  const rateLimitId = await reservePhoneVerificationSend({
    phoneNumber: normalizedPhoneNumber,
    memberId,
  })
  const verifier = getRecaptchaVerifier()

  try {
    await verifier.render()
    confirmationResult = await signInWithPhoneNumber(
      firebaseAuth,
      normalizedPhoneNumber,
      verifier,
    )
    await markPhoneVerificationSmsSent(rateLimitId)
    return normalizedPhoneNumber
  } catch (error) {
    await releasePhoneVerificationSmsReservation(rateLimitId).catch(() => undefined)
    resetRecaptchaVerifier()
    throw new Error(firebasePhoneAuthMessage(error), { cause: error })
  }
}

export async function confirmPhoneVerificationCode(
  code: string,
): Promise<ConfirmedPhoneVerification> {
  const verificationCode = normalizeVerificationCode(code)
  if (!verificationCode) {
    throw new Error('請輸入驗證碼')
  }
  if (verificationCode.length !== smsVerificationCodeLength) {
    throw new Error(`請輸入 ${smsVerificationCodeLength} 位數驗證碼`)
  }
  if (!confirmationResult) {
    throw new Error('請先取得簡訊驗證碼')
  }

  try {
    const credential = await confirmationResult.confirm(verificationCode)
    const phoneNumber = credential.user.phoneNumber
    if (!phoneNumber) {
      throw new Error('無法取得已驗證的手機號碼')
    }
    return {
      phoneNumber,
      firebasePhoneUid: credential.user.uid,
    }
  } catch (error) {
    throw new Error(firebasePhoneAuthMessage(error), { cause: error })
  }
}

function getRecaptchaVerifier() {
  if (recaptchaVerifier) return recaptchaVerifier

  recaptchaVerifier = new RecaptchaVerifier(
    firebaseAuth,
    'phone-recaptcha-container',
    {
      size: 'invisible',
      'expired-callback': () => {
        resetRecaptchaVerifier()
      },
    },
  )
  return recaptchaVerifier
}

function resetRecaptchaVerifier() {
  try {
    recaptchaVerifier?.clear()
  } catch {
    // Firebase can throw if the widget was never rendered.
  }
  recaptchaVerifier = undefined
}

async function reservePhoneVerificationSend(input: {
  phoneNumber: string
  memberId?: string
}) {
  const rateLimitId = await phoneRateLimitId(input.phoneNumber)
  const rateLimitRef = doc(firestore, 'phoneVerificationRateLimits', rateLimitId)
  const nowMs = Date.now()

  await runTransaction(firestore, async (transaction) => {
    const snapshot = await transaction.get(rateLimitRef)
    const data = snapshot.data() ?? {}
    const lastSentMs = firestoreDateMs(data.lastSentAt)
    const reservedUntilMs = firestoreDateMs(data.reservedUntilAt)
    const blockedUntilMs = Math.max(lastSentMs + smsSendCooldownMs, reservedUntilMs)

    if (blockedUntilMs > nowMs) {
      const remainingSeconds = Math.ceil((blockedUntilMs - nowMs) / 1000)
      throw new Error(
        `同一個手機號碼 1 分鐘內只能發送一次，請 ${remainingSeconds} 秒後再試`,
      )
    }

    transaction.set(
      rateLimitRef,
      {
        phoneHash: rateLimitId,
        phoneLastFour: input.phoneNumber.slice(-4),
        reservedUntilAt: Timestamp.fromMillis(nowMs + smsSendCooldownMs),
        lastReservedAt: serverTimestamp(),
        lastMemberId: input.memberId ?? null,
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    )
  })

  return rateLimitId
}

async function markPhoneVerificationSmsSent(rateLimitId: string) {
  await setDoc(
    doc(firestore, 'phoneVerificationRateLimits', rateLimitId),
    {
      lastSentAt: serverTimestamp(),
      reservedUntilAt: null,
      sentCount: increment(1),
      updatedAt: serverTimestamp(),
    },
    { merge: true },
  )
}

async function releasePhoneVerificationSmsReservation(rateLimitId: string) {
  await setDoc(
    doc(firestore, 'phoneVerificationRateLimits', rateLimitId),
    {
      reservedUntilAt: null,
      lastFailedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
    { merge: true },
  )
}

async function phoneRateLimitId(phoneNumber: string) {
  const digest = await window.crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(phoneNumber),
  )
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

function firestoreDateMs(value: unknown) {
  if (!value) return 0
  if (value instanceof Timestamp) return value.toMillis()
  if (
    typeof value === 'object' &&
    'toMillis' in value &&
    typeof (value as { toMillis?: unknown }).toMillis === 'function'
  ) {
    return (value as { toMillis: () => number }).toMillis()
  }
  if (value instanceof Date) return value.getTime()
  if (typeof value === 'string') {
    const parsed = new Date(value).getTime()
    return Number.isFinite(parsed) ? parsed : 0
  }
  return 0
}

function firebasePhoneAuthMessage(error: unknown) {
  const code =
    typeof error === 'object' && error && 'code' in error
      ? String((error as { code?: unknown }).code)
      : ''

  if (code.includes('invalid-phone-number')) {
    return '手機號碼格式不正確，請重新確認'
  }
  if (code.includes('invalid-verification-code')) {
    return '驗證碼不正確，請重新輸入'
  }
  if (code.includes('too-many-requests')) {
    return '驗證次數過多，請稍後再試'
  }
  if (code.includes('quota-exceeded')) {
    return '簡訊發送額度已達上限，請稍後再試'
  }
  if (code.includes('captcha-check-failed')) {
    return '安全驗證失敗，請重新取得驗證碼'
  }
  if (code.includes('operation-not-allowed')) {
    return '尚未啟用 Firebase 手機登入功能'
  }
  if (code.includes('configuration-not-found')) {
    return '尚未設定 Firebase Authentication，請先在 Firebase Console 啟用 Authentication 與手機登入'
  }

  if (error instanceof Error && error.message) {
    return error.message
  }
  return '手機驗證失敗，請稍後再試'
}
