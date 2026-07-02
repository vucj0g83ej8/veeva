import { MessageSquareText, Phone, ShieldCheck } from 'lucide-react'
import { useMemo, useState } from 'react'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import {
  confirmPhoneVerificationCode,
  normalizePhoneNumber,
  normalizeVerificationCode,
  resetPhoneVerificationSession,
  sendPhoneVerificationCode,
} from '../services/phoneVerification'

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
    setMessage('')
    try {
      const normalizedPhoneNumber = await sendPhoneVerificationCode(
        phoneNumber,
        app.member?.id,
      )
      setSentPhoneNumber(normalizedPhoneNumber)
      setVerificationCode('')
      setMessage('驗證碼已送出，請查看手機簡訊。')
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
              發送驗證碼
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
                disabled={busy}
                onClick={() => {
                  resetPhoneVerificationSession()
                  setSentPhoneNumber('')
                  setVerificationCode('')
                  setMessage('')
                  setError('')
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
