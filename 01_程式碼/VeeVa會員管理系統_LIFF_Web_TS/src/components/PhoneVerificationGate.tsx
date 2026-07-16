import { MessageSquareText, Phone, ShieldCheck } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import type { VeevaAppState } from '../hooks/useVeevaApp'

interface PhoneVerificationGateProps {
  app: VeevaAppState
}

export function PhoneVerificationGate({ app }: PhoneVerificationGateProps) {
  const [phoneNumber, setPhoneNumber] = useState(app.member?.phoneNumber ?? '')
  const [sentPhoneNumber, setSentPhoneNumber] = useState('')
  const [verificationCode, setVerificationCode] = useState('')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  const [resendAvailableAt, setResendAvailableAt] = useState(0)
  const [countdownNow, setCountdownNow] = useState(() => Date.now())
  const resendSeconds = Math.max(
    0,
    Math.ceil((resendAvailableAt - countdownNow) / 1000),
  )

  useEffect(() => {
    if (!resendAvailableAt) return
    const intervalId = window.setInterval(
      () => setCountdownNow(Date.now()),
      500,
    )
    return () => window.clearInterval(intervalId)
  }, [resendAvailableAt])

  const formattedPhonePreview = useMemo(() => {
    try {
      return phoneNumber.trim() ? normalizePhoneNumber(phoneNumber) : ''
    } catch {
      return ''
    }
  }, [phoneNumber])

  async function sendCode() {
    setBusy(true)
    setError('')
    setMessage('正在發送驗證碼，請稍候...')
    try {
      const { sendPhoneVerificationCode } = await import(
        '../services/phoneVerification'
      )
      const normalizedPhoneNumber = await sendPhoneVerificationCode(
        phoneNumber,
        app.member?.id,
      )
      setSentPhoneNumber(normalizedPhoneNumber)
      setVerificationCode('')
      setCountdownNow(Date.now())
      setResendAvailableAt(Date.now() + 60_000)
      setMessage(
        '簡訊發送要求已受理，通常會在 1 分鐘內抵達，尖峰時可能稍有延遲。',
      )
    } catch (sendError) {
      setError(sendError instanceof Error ? sendError.message : String(sendError))
    } finally {
      setBusy(false)
    }
  }

  async function confirmCode() {
    setBusy(true)
    setError('')
    setMessage('')
    try {
      const { confirmPhoneVerificationCode } = await import(
        '../services/phoneVerification'
      )
      const result = await confirmPhoneVerificationCode(verificationCode)
      await app.completePhoneVerification(result)
      setMessage('手機驗證完成。')
    } catch (confirmError) {
      setError(
        confirmError instanceof Error ? confirmError.message : String(confirmError),
      )
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="phone-verification-page">
      <article className="phone-verification-panel">
        <div className="phone-verification-icon">
          <ShieldCheck size={30} />
        </div>
        <p className="eyebrow">會員安全驗證</p>
        <h2>請完成手機號碼驗證</h2>
        <p className="phone-verification-copy">
          LINE 登入成功後，請再驗證手機號碼，完成後即可使用活動、兌換券與會員功能。
        </p>

        <div className="phone-verification-form">
          <label className="phone-verification-field">
            <span>
              <Phone size={18} />
              手機號碼
            </span>
            <input
              inputMode="tel"
              placeholder="0912345678"
              value={phoneNumber}
              disabled={busy || Boolean(sentPhoneNumber)}
              onChange={(event) => setPhoneNumber(event.target.value)}
            />
          </label>

          {!sentPhoneNumber && (
            <button
              className="primary-button phone-verification-button"
              type="button"
              disabled={busy}
              onClick={sendCode}
            >
              <MessageSquareText size={19} />
              {busy ? '發送中...' : '發送驗證碼'}
            </button>
          )}

          {sentPhoneNumber && (
            <>
              <label className="phone-verification-field">
                <span>
                  <MessageSquareText size={18} />
                  簡訊驗證碼
                </span>
                <input
                  autoComplete="one-time-code"
                  inputMode="numeric"
                  maxLength={6}
                  pattern="[0-9]*"
                  placeholder="輸入驗證碼"
                  value={verificationCode}
                  disabled={busy}
                  onChange={(event) =>
                    setVerificationCode(
                      normalizeVerificationCode(event.currentTarget.value),
                    )
                  }
                />
              </label>
              <button
                className="primary-button phone-verification-button"
                type="button"
                disabled={busy || verificationCode.length !== 6}
                onClick={confirmCode}
              >
                <ShieldCheck size={19} />
                確認驗證
              </button>
              <button
                className="text-action phone-verification-reset"
                type="button"
                disabled={busy || resendSeconds > 0}
                onClick={sendCode}
              >
                {resendSeconds > 0
                  ? `若未收到，可於 ${resendSeconds} 秒後重新發送`
                  : '沒有收到簡訊？重新發送'}
              </button>
              <button
                className="text-action phone-verification-reset"
                type="button"
                disabled={busy}
                onClick={async () => {
                  const { resetPhoneVerificationSession } = await import(
                    '../services/phoneVerification'
                  )
                  resetPhoneVerificationSession()
                  setSentPhoneNumber('')
                  setVerificationCode('')
                  setMessage('')
                  setError('')
                  setResendAvailableAt(0)
                }}
              >
                重新輸入手機號碼
              </button>
            </>
          )}
        </div>

        {formattedPhonePreview && !sentPhoneNumber && (
          <p className="phone-verification-hint">
            將以 {formattedPhonePreview} 發送驗證碼
          </p>
        )}
        {sentPhoneNumber && (
          <p className="phone-verification-hint">
            驗證碼已發送至 {sentPhoneNumber}
          </p>
        )}
        {message && <p className="phone-verification-message">{message}</p>}
        {error && <p className="phone-verification-error">{error}</p>}
      </article>
      <div id="phone-recaptcha-container" />
    </section>
  )
}

function normalizePhoneNumber(input: string) {
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

function normalizeVerificationCode(input: string) {
  const firstSixDigitCode = input.match(/\d{6}/)?.[0]
  if (firstSixDigitCode) return firstSixDigitCode
  return input.replace(/\D/g, '').slice(0, 6)
}
