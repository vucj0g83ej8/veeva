import { AlertCircle, RefreshCw } from 'lucide-react'
import type { VeevaAppState } from '../hooks/useVeevaApp'

interface AuthNoticeProps {
  app: VeevaAppState
}

export function AuthNotice({ app }: AuthNoticeProps) {
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

  return null
}
