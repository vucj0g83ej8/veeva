import {
  ChevronRight,
  Edit3,
  Headphones,
  LogOut,
  Mail,
  RefreshCw,
  Save,
  Send,
  Share2,
  Ticket,
  UserPlus,
  UserRound,
  UsersRound,
  X,
} from 'lucide-react'
import { useMemo, useState, type FormEvent, type ReactNode } from 'react'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import type { VeevaMember, VeevaMemberStatus } from '../types/veeva'
import { formatDateTime } from '../utils/date'
import { inviteUrlForShareCode } from '../utils/inviteUrl'

interface PageProps {
  app: VeevaAppState
}

export function MemberPage({ app }: PageProps) {
  const [recordsOpen, setRecordsOpen] = useState(false)
  const [profileEditorOpen, setProfileEditorOpen] = useState(false)
  const [copied, setCopied] = useState(false)
  const inviteUrl = useMemo(() => {
    if (!app.member) return ''
    return inviteUrlForShareCode(app.member.shareCode)
  }, [app.member])

  if (!app.member) {
    return (
      <section className="member-login-page">
        <article className="member-login-panel">
          <div className="member-login-icon">
            <UserRound size={38} />
          </div>
          <h2>登入會員</h2>
          <p>使用 LINE 登入後即可查看兌換券、邀請紀錄與會員功能。</p>
          <button
            className="member-line-login-button"
            disabled={app.busy}
            type="button"
            onClick={app.login}
          >
            使用 LINE 登入
          </button>
        </article>
      </section>
    )
  }

  const status = memberStatusMeta(app.member, app.disabled)
  const memberSubtitle = memberSubtitleFor(app.member)
  const visibleCouponCount = app.memberRewards.length
  const copyInviteUrl = async () => {
    await navigator.clipboard.writeText(inviteUrl)
    setCopied(true)
    window.setTimeout(() => setCopied(false), 1600)
  }

  return (
    <section className="member-page">
      <p className="member-page-subtitle">
        {app.member.status === 'verified'
          ? '已完成資格驗證'
          : '完成問卷後即可啟用完整會員功能。'}
      </p>

      <article className="member-card member-profile-card">
        <div className="member-profile-row">
          {app.member.avatarUrl ? (
            <img className="member-avatar" src={app.member.avatarUrl} alt="" />
          ) : (
            <div className="member-avatar placeholder">
              <UserRound size={30} />
            </div>
          )}
          <div className="member-profile-copy">
            <h2>{app.member.name}</h2>
            <p>{memberSubtitle}</p>
          </div>
          <span className={`member-status-tag ${status.tone}`}>{status.label}</span>
        </div>

        <div className="member-metrics">
          <div className="member-metric-tile">
            <span className="member-metric-icon">
              <Ticket size={21} />
            </span>
            <span>已得券</span>
            <strong>{visibleCouponCount}</strong>
          </div>
          <div className="member-metric-tile">
            <span className="member-metric-icon">
              <UserPlus size={21} />
            </span>
            <span>已邀請</span>
            <strong>{app.member.invitedCount}</strong>
          </div>
        </div>
      </article>

      <article className="member-feature-card">
        <h2>會員功能</h2>
        <div className="member-feature-list">
          <MemberFeatureButton
            icon={<Edit3 size={21} />}
            title="編輯會員資料"
            subtitle="更新姓名與 email"
            onClick={() => setProfileEditorOpen(true)}
          />
          <MemberFeatureButton
            icon={<UsersRound size={21} />}
            title="邀請紀錄"
            subtitle="追蹤好友邀請與推薦成果"
            onClick={() => setRecordsOpen(true)}
          />
          <MemberFeatureButton
            icon={<Headphones size={21} />}
            title="客服協助"
            subtitle="回報兌換問題或會員資料異常"
          />
        </div>
      </article>

      <article className="invite-card member-invite-card">
        <div className="member-invite-main">
          <div className="member-invite-icon">
            <Share2 size={23} />
          </div>
          <div className="member-invite-copy">
            <h2>邀請好友</h2>
            <p>邀請碼 {app.member.shareCode}</p>
          </div>
          <button
            className="member-share-button"
            disabled={app.busy}
            type="button"
            onClick={app.shareInvite}
          >
            <Send size={18} />
            分享給好友
          </button>
        </div>
        <button
          className="member-copy-link-button"
          type="button"
          onClick={() => void copyInviteUrl()}
        >
          {copied ? '已複製邀請連結' : '複製邀請連結'}
        </button>
      </article>

      <button className="member-logout-button" type="button" onClick={app.logout}>
        <LogOut size={18} />
        登出
      </button>

      {recordsOpen && (
        <div className="dialog-backdrop" role="presentation">
          <section className="dialog" role="dialog" aria-modal="true">
            <div className="dialog-header">
              <div className="dialog-title">
                <span>
                  <UsersRound size={21} />
                </span>
                <h2>邀請紀錄</h2>
              </div>
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
                <h3>目前尚無邀請成功紀錄</h3>
              </div>
            ) : (
              <>
                <div className="record-dialog-summary">
                  <span>好友透過分享連結完成 LINE 登入</span>
                  <strong>{app.referrals.length} 位</strong>
                </div>
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
                        <strong>{record.referredName || 'LINE 會員'}</strong>
                        <span>
                          {record.createdAt
                            ? `登入時間 ${formatDateTime(record.createdAt)}`
                            : '登入時間同步中'}
                        </span>
                      </div>
                      <em>已登入</em>
                    </div>
                  ))}
                </div>
              </>
            )}
            <div className="dialog-actions">
              <button
                className="secondary-button"
                type="button"
                onClick={app.refreshMemberData}
              >
                <RefreshCw size={17} />
                重新整理
              </button>
              <button
                className="primary-button compact"
                type="button"
                onClick={() => setRecordsOpen(false)}
              >
                關閉
              </button>
            </div>
          </section>
        </div>
      )}

      {profileEditorOpen && (
        <EditMemberProfileDialog
          busy={app.busy}
          member={app.member}
          onClose={() => setProfileEditorOpen(false)}
          onSave={app.updateMemberProfile}
        />
      )}
    </section>
  )
}

interface MemberFeatureButtonProps {
  icon: ReactNode
  title: string
  subtitle: string
  onClick?: () => void
}

function MemberFeatureButton({
  icon,
  title,
  subtitle,
  onClick,
}: MemberFeatureButtonProps) {
  return (
    <button
      className="member-feature-row"
      disabled={!onClick}
      type="button"
      onClick={onClick}
    >
      <span className="member-feature-icon">{icon}</span>
      <span className="member-feature-copy">
        <strong>{title}</strong>
        <em>{subtitle}</em>
      </span>
      <ChevronRight size={19} />
    </button>
  )
}

interface EditMemberProfileDialogProps {
  busy: boolean
  member: VeevaMember
  onClose: () => void
  onSave: (input: { name: string; email: string }) => Promise<VeevaMember>
}

function EditMemberProfileDialog({
  busy,
  member,
  onClose,
  onSave,
}: EditMemberProfileDialogProps) {
  const [name, setName] = useState(member.name)
  const [email, setEmail] = useState(member.email ?? '')
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)
  const isSubmitting = busy || saving

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const nextName = name.trim()
    const nextEmail = email.trim()
    if (!nextName) {
      setError('請輸入姓名')
      return
    }
    if (nextEmail && !isValidEmail(nextEmail)) {
      setError('請輸入正確的 email 格式')
      return
    }
    setSaving(true)
    setError('')
    try {
      await onSave({ name: nextName, email: nextEmail })
      onClose()
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : String(saveError))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="dialog-backdrop" role="presentation">
      <section className="dialog member-edit-dialog" role="dialog" aria-modal="true">
        <div className="dialog-header">
          <div className="dialog-title">
            <span>
              <Edit3 size={21} />
            </span>
            <h2>編輯會員資料</h2>
          </div>
          <button
            className="icon-button"
            type="button"
            aria-label="關閉"
            disabled={isSubmitting}
            onClick={onClose}
          >
            <X size={20} />
          </button>
        </div>

        <form className="member-edit-form" noValidate onSubmit={submit}>
          <label className="member-form-field">
            <span>
              <UserRound size={17} />
              姓名
            </span>
            <input
              maxLength={40}
              placeholder="請輸入姓名"
              value={name}
              onChange={(event) => setName(event.target.value)}
            />
          </label>

          <label className="member-form-field">
            <span>
              <Mail size={17} />
              Email
            </span>
            <input
              inputMode="email"
              maxLength={80}
              placeholder="name@example.com"
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
            />
          </label>

          {error && <p className="member-form-error">{error}</p>}

          <div className="dialog-actions">
            <button
              className="secondary-button"
              disabled={isSubmitting}
              type="button"
              onClick={onClose}
            >
              取消
            </button>
            <button
              className="primary-button compact"
              disabled={isSubmitting}
              type="submit"
            >
              <Save size={17} />
              {isSubmitting ? '儲存中' : '儲存'}
            </button>
          </div>
        </form>
      </section>
    </div>
  )
}

function memberStatusMeta(member: VeevaMember, disabled: boolean) {
  if (disabled) return { label: '停用', tone: 'danger' }
  const statusMap: Record<VeevaMemberStatus, { label: string; tone: string }> = {
    guest: { label: '未登入', tone: 'muted' },
    loggedIn: { label: '未完成', tone: 'warning' },
    pendingReview: { label: '審核中', tone: 'pending' },
    verified: { label: '已驗證', tone: 'success' },
  }
  return statusMap[member.status] ?? statusMap.loggedIn
}

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
}

function memberSubtitleFor(member: VeevaMember) {
  if (member.status === 'verified') {
    const profileText = [member.hospital, member.department]
      .map((item) => item.trim())
      .filter(Boolean)
      .join(' | ')
    return profileText || '會員資料已完成'
  }
  if (member.status === 'pendingReview') return '會員資料審核中'
  return '尚未完成會員流程'
}
