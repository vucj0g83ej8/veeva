import {
  Copy,
  LogOut,
  Send,
  ShieldCheck,
  UserRound,
  UsersRound,
  X,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import { formatDateTime } from '../utils/date'
import { inviteUrlForShareCode } from '../utils/inviteUrl'

interface PageProps {
  app: VeevaAppState
}

export function MemberPage({ app }: PageProps) {
  const [recordsOpen, setRecordsOpen] = useState(false)
  const inviteUrl = useMemo(() => {
    if (!app.member) return ''
    return inviteUrlForShareCode(app.member.shareCode)
  }, [app.member])

  if (!app.member) {
    return (
      <section className="member-login-panel">
        <div className="member-avatar placeholder">
          <UserRound size={32} />
        </div>
        <h2>LINE 會員登入</h2>
        <button
          className="primary-button"
          disabled={app.busy}
          type="button"
          onClick={app.login}
        >
          LINE 登入
        </button>
      </section>
    )
  }

  return (
    <section className="stack">
      <article className="member-card">
        <div className="member-profile">
          {app.member.avatarUrl ? (
            <img className="member-avatar" src={app.member.avatarUrl} alt="" />
          ) : (
            <div className="member-avatar placeholder">
              <UserRound size={30} />
            </div>
          )}
          <div>
            <h2>{app.member.name}</h2>
            <div className="detail-row compact">
              <ShieldCheck size={17} />
              <span>{app.disabled ? '帳號停用' : '會員啟用'}</span>
            </div>
          </div>
        </div>
        <div className="member-metrics">
          <div>
            <strong>{app.member.invitedCount}</strong>
            <span>邀請</span>
          </div>
          <div>
            <strong>{app.member.earnedCoupons}</strong>
            <span>兌換券</span>
          </div>
        </div>
      </article>

      <article className="invite-card">
        <div className="card-topline">
          <span className="soft-tag">邀請好友</span>
          <span className="muted">{app.member.shareCode}</span>
        </div>
        <div className="invite-url">{inviteUrl}</div>
        <div className="button-row">
          <button className="primary-button" type="button" onClick={app.shareInvite}>
            <Send size={18} />
            分享給好友
          </button>
          <button
            className="secondary-button"
            type="button"
            onClick={() => void navigator.clipboard.writeText(inviteUrl)}
          >
            <Copy size={18} />
            複製
          </button>
        </div>
      </article>

      <div className="button-row">
        <button
          className="secondary-button wide"
          type="button"
          onClick={() => setRecordsOpen(true)}
        >
          <UsersRound size={18} />
          邀請紀錄
        </button>
        <button className="ghost-button" type="button" onClick={app.logout}>
          <LogOut size={18} />
          登出
        </button>
      </div>

      {recordsOpen && (
        <div className="dialog-backdrop" role="presentation">
          <section className="dialog" role="dialog" aria-modal="true">
            <div className="dialog-header">
              <h2>邀請紀錄</h2>
              <button
                className="icon-button"
                type="button"
                aria-label="關閉"
                onClick={() => setRecordsOpen(false)}
              >
                <X size={20} />
              </button>
            </div>

            {app.referrals.length === 0 ? (
              <div className="empty-state compact">
                <UsersRound size={26} />
                <h3>目前沒有邀請紀錄</h3>
              </div>
            ) : (
              <div className="record-list">
                {app.referrals.map((record) => (
                  <div className="record-row" key={record.id}>
                    {record.referredAvatarUrl ? (
                      <img src={record.referredAvatarUrl} alt="" />
                    ) : (
                      <div className="record-avatar">
                        <UserRound size={18} />
                      </div>
                    )}
                    <div>
                      <strong>{record.referredName}</strong>
                      <span>{formatDateTime(record.createdAt)}</span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>
        </div>
      )}
    </section>
  )
}
