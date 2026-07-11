import { CheckCircle2, ShieldCheck, Ticket, XCircle } from 'lucide-react'
import { doc, getDoc } from 'firebase/firestore'
import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { useParams } from 'react-router-dom'
import { firestore } from '../services/firebase'

type VoucherState = {
  verificationCode: string
  status: string
}

export function TestVoucherPage() {
  const { voucherId } = useParams()
  const [voucher, setVoucher] = useState<VoucherState | null>(null)
  const [code, setCode] = useState('')
  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [result, setResult] = useState<'success' | 'error' | null>(null)

  useEffect(() => {
    let active = true
    async function loadVoucher() {
      if (!voucherId) {
        setLoadError('找不到測試券資料')
        setLoading(false)
        return
      }
      try {
        const snapshot = await getDoc(
          doc(firestore, 'rewardVouchers', voucherId),
        )
        if (!active) return
        if (!snapshot.exists()) {
          setLoadError('找不到測試券資料')
          return
        }
        const data = snapshot.data()
        setVoucher({
          verificationCode: String(data.verificationCode ?? '').trim(),
          status: String(data.status ?? 'available'),
        })
      } catch {
        if (active) setLoadError('測試券載入失敗，請稍後再試')
      } finally {
        if (active) setLoading(false)
      }
    }
    void loadVoucher()
    return () => {
      active = false
    }
  }, [voucherId])

  const verifyCode = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!voucher || voucher.status === 'redeemed') return
    setResult(code === voucher.verificationCode ? 'success' : 'error')
  }

  return (
    <main className="test-voucher-page">
      <section
        className="test-voucher-panel"
        aria-labelledby="test-voucher-title"
      >
        <span className="test-voucher-icon" aria-hidden="true">
          <Ticket size={34} />
        </span>
        <p className="test-voucher-eyebrow">VeeVa 測試券</p>
        <h1 id="test-voucher-title">7-ELEVEN 數位商品券</h1>
        <p className="test-voucher-description">
          請貼上剛才複製的 5 位數驗證碼，確認測試兌換流程是否正常。
        </p>

        {loading ? <p className="test-voucher-state">測試券載入中</p> : null}
        {loadError ? (
          <div className="test-voucher-result error">
            <XCircle size={22} />
            {loadError}
          </div>
        ) : null}

        {!loading && voucher ? (
          <form className="test-voucher-form" onSubmit={verifyCode}>
            <label htmlFor="test-voucher-code">驗證碼</label>
            <input
              id="test-voucher-code"
              autoComplete="one-time-code"
              inputMode="numeric"
              maxLength={5}
              placeholder="請輸入 5 位數驗證碼"
              value={code}
              onChange={(event) => {
                setCode(event.target.value.replace(/\D/g, '').slice(0, 5))
                setResult(null)
              }}
            />
            <button type="submit" disabled={code.length !== 5}>
              <ShieldCheck size={21} />
              驗證並測試
            </button>
          </form>
        ) : null}

        {result === 'success' ? (
          <div className="test-voucher-result success">
            <CheckCircle2 size={22} />
            驗證成功，測試兌換流程正常。
          </div>
        ) : null}
        {result === 'error' ? (
          <div className="test-voucher-result error">
            <XCircle size={22} />
            驗證碼不正確，請重新輸入。
          </div>
        ) : null}

        <p className="test-voucher-note">
          此頁僅供系統測試，不會產生實際的 7-ELEVEN 商品兌換。
        </p>
      </section>
    </main>
  )
}
