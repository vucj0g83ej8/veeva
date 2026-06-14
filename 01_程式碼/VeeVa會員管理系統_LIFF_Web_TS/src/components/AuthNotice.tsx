import { AlertCircle, LogIn, RefreshCw } from 'lucide-react'
import { useLocation } from 'react-router-dom'
import type { VeevaAppState } from '../hooks/useVeevaApp'

interface AuthNoticeProps {
  app: VeevaAppState
}

export function AuthNotice({ app }: AuthNoticeProps) {
  const location = useLocation()
  const hasPageLoginPanel =
    location.pathname === '/member' ||
    location.pathname === '/coupons' ||
    location.pathname.startsWith('/r/')

  if (app.disabled) {
    return (
      <section className="notice danger">
        <AlertCircle size={19} />
        <div>
          <strong>帳號已停用</strong>
          <p>請聯絡管理者確認會員狀態。</p>
        </div>
      </section>
    )
  }

  if (app.error) {
    return (
      <section className="notice warning">
        <AlertCircle size={19} />
        <div>
          <strong>系統訊息</strong>
          <p>{app.error}</p>
        </div>
        <button type="button" className="text-action" onClick={app.refresh}>
          <RefreshCw size={16} />
          重試
        </button>
      </section>
    )
  }

  if (!app.liffSession?.loggedIn && !hasPageLoginPanel) {
    return (
      <section className="notice">
        <LogIn size={19} />
        <div>
          <strong>尚未登入 LINE</strong>
          <p>登入後可查看會員資料、兌換券與邀請紀錄。</p>
        </div>
        <button
          className="text-action"
          disabled={app.busy}
          type="button"
          onClick={app.login}
        >
          LINE 登入
        </button>
      </section>
    )
  }

  return null
}
