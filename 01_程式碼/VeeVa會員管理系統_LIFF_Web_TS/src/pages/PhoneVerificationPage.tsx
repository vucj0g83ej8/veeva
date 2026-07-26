import { ArrowLeft, CheckCircle2, ShieldCheck } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { PhoneVerificationGate } from '../components/PhoneVerificationGate'
import type { VeevaAppState } from '../hooks/useVeevaApp'

interface PhoneVerificationPageProps {
  app: VeevaAppState
}

export function PhoneVerificationPage({ app }: PhoneVerificationPageProps) {
  const navigate = useNavigate()

  if (!app.member) {
    return (
      <section className="phone-verification-page">
        <article className="phone-verification-panel">
          <div className="phone-verification-icon">
            <ShieldCheck size={30} />
          </div>
          <h2>請先使用 LINE 登入</h2>
          <p className="phone-verification-copy">
            登入會員後即可依需要完成手機號碼驗證。
          </p>
          <button
            className="primary-button phone-verification-button"
            type="button"
            disabled={app.busy}
            onClick={app.login}
          >
            使用 LINE 登入
          </button>
        </article>
      </section>
    )
  }

  if (!app.member.phoneVerified) {
    return <PhoneVerificationGate app={app} />
  }

  return (
    <section className="phone-verification-page">
      <article className="phone-verification-panel phone-verification-complete">
        <div className="phone-verification-icon">
          <CheckCircle2 size={30} />
        </div>
        <p className="eyebrow">會員安全驗證</p>
        <h2>手機號碼已驗證</h2>
        <p className="phone-verification-copy">
          此會員已完成手機號碼驗證，不需要再次操作。
        </p>
        {app.member.phoneNumber ? (
          <p className="phone-verification-number">{app.member.phoneNumber}</p>
        ) : null}
        <button
          className="secondary-button phone-verification-button"
          type="button"
          onClick={() => navigate('/member')}
        >
          <ArrowLeft size={18} />
          回會員中心
        </button>
      </article>
    </section>
  )
}
