import { MessageCircle, RefreshCw, UserPlus } from 'lucide-react'
import { useState } from 'react'
import type { VeevaAppState } from '../hooks/useVeevaApp'

interface OfficialAccountFriendGateProps {
  app: VeevaAppState
}

export function OfficialAccountFriendGate({
  app,
}: OfficialAccountFriendGateProps) {
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  async function joinOfficialAccount() {
    setBusy(true)
    setMessage('')
    setError('')
    try {
      await app.requestOfficialAccountFriendship()
      setMessage('加入後請回到此頁重新檢查。')
    } catch (joinError) {
      setError(joinError instanceof Error ? joinError.message : String(joinError))
    } finally {
      setBusy(false)
    }
  }

  async function recheckFriendship() {
    setBusy(true)
    setMessage('')
    setError('')
    try {
      const result = await app.refreshOfficialAccountFriendship()
      if (!result.friend) {
        setMessage('目前尚未確認加入官方帳號。')
      }
    } catch (checkError) {
      setError(
        checkError instanceof Error ? checkError.message : String(checkError),
      )
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="official-account-page">
      <article className="official-account-panel">
        <div className="official-account-icon">
          <MessageCircle size={30} />
        </div>
        <p className="eyebrow">LINE 官方帳號</p>
        <h2>請先加入官方帳號</h2>
        <p className="official-account-copy">
          加入後才能接收審核通知、兌換券通知與活動提醒。
        </p>

        <div className="official-account-actions">
          <button
            className="primary-button official-account-button"
            type="button"
            disabled={busy}
            onClick={joinOfficialAccount}
          >
            <UserPlus size={19} />
            加入官方帳號
          </button>
          <button
            className="secondary-button official-account-button"
            type="button"
            disabled={busy}
            onClick={recheckFriendship}
          >
            <RefreshCw size={18} />
            我已加入，重新檢查
          </button>
        </div>

        {!app.officialAccountFriendshipSupported && (
          <p className="official-account-hint">
            目前無法自動確認加入狀態，請確認 LIFF 已啟用官方帳號好友檢查。
          </p>
        )}
        {message && <p className="official-account-message">{message}</p>}
        {error && <p className="official-account-error">{error}</p>}
        {app.officialAccountFriendshipError && !error && (
          <p className="official-account-error">
            {app.officialAccountFriendshipError}
          </p>
        )}
      </article>
    </section>
  )
}
