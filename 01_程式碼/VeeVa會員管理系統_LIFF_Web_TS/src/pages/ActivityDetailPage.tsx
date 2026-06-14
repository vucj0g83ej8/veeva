import {
  ArrowLeft,
  CalendarDays,
  CheckCircle2,
  ChevronDown,
  Clock3,
  ExternalLink,
  MapPin,
  Megaphone,
  Microscope,
  NotebookPen,
  Send,
  Share2,
  Stethoscope,
  Tag,
  UserRound,
  UsersRound,
} from 'lucide-react'
import { useMemo, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import type { VeevaActivity } from '../types/veeva'
import { activityFlowFor } from '../utils/activityFlow'

interface PageProps {
  app: VeevaAppState
}

export function ActivityDetailPage({ app }: PageProps) {
  const { activityId = '' } = useParams()
  const decodedActivityId = safeDecode(activityId)
  const activity = app.bootstrap.activities.find(
    (item) => item.id === decodedActivityId,
  )

  if (!activity) {
    return (
      <section className="empty-state">
        <Megaphone size={30} />
        <h2>找不到活動</h2>
        <p>這個活動可能已下架或尚未發布。</p>
        <Link className="secondary-button" to="/activities">
          <ArrowLeft size={18} />
          回活動列表
        </Link>
      </section>
    )
  }

  return <ActivityDetailContent activity={activity} app={app} />
}

function ActivityDetailContent({
  activity,
  app,
}: {
  activity: VeevaActivity
  app: VeevaAppState
}) {
  const flow = useMemo(() => activityFlowFor(activity), [activity])
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState(false)
  const statusLabel = activityStatusLabel(activity)
  const location = activity.location ?? fallbackLocation(activity)

  async function handlePrimaryAction() {
    setMessage('')

    if (activity.type === 'survey') {
      if (!activity.surveyUrl) {
        setMessage('這個問卷活動尚未設定問卷連結。')
        return
      }
      window.open(activity.surveyUrl, '_blank', 'noopener,noreferrer')
      return
    }

    if (activity.type === 'external' || activity.type === 'task') {
      if (!activity.actionUrl) {
        setMessage('這個活動尚未設定操作連結，請等待主辦單位更新。')
        return
      }
      window.open(activity.actionUrl, '_blank', 'noopener,noreferrer')
      return
    }

    if (activity.type === 'referral') {
      await app.shareInvite()
      return
    }

    if (!app.member) {
      await app.login()
      return
    }

    if (activity.type === 'registration') {
      setBusy(true)
      try {
        const { registerActivity } = await import('../services/veevaRepository')
        await registerActivity({ activity, member: app.member })
        await app.refreshMemberData()
        setMessage('已完成報名，我們會保留你的活動報名紀錄。')
      } catch (error) {
        setMessage(error instanceof Error ? error.message : String(error))
      } finally {
        setBusy(false)
      }
      return
    }

    if (activity.type === 'checkin') {
      setMessage('簽到功能會搭配現場 QR Code 或指定驗證流程使用。')
    }
  }

  async function handleShareAction() {
    setMessage('')
    const shareUrl = new URL(
      `/activities/${encodeURIComponent(activity.id)}`,
      window.location.origin,
    ).toString()
    const shareData = {
      title: activity.title,
      text: activity.description,
      url: shareUrl,
    }
    const browserNavigator = window.navigator as Navigator & {
      clipboard?: Clipboard
      share?: (data: ShareData) => Promise<void>
    }

    try {
      if (typeof browserNavigator.share === 'function') {
        await browserNavigator.share(shareData)
        return
      }
      if (!browserNavigator.clipboard) {
        setMessage('目前無法開啟分享功能，請手動複製網址分享。')
        return
      }
      await browserNavigator.clipboard.writeText(shareUrl)
      setMessage('已複製活動連結，可以貼給朋友分享。')
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') {
        return
      }
      setMessage('目前無法開啟分享功能，請稍後再試。')
    }
  }

  return (
    <article className="activity-detail-page">
      <div className="activity-detail-nav">
        <Link aria-label="回活動列表" className="activity-detail-back" to="/activities">
          <ArrowLeft size={24} />
        </Link>
        <strong>活動資訊</strong>
        <span aria-hidden="true" />
      </div>

      <div className="activity-detail-content">
        <section className={`activity-detail-hero ${activity.type}`}>
          {activity.imageUrl ? (
            <img
              className="activity-detail-hero-image"
              src={activity.imageUrl}
              alt=""
            />
          ) : (
            <div className={`activity-detail-hero-art ${activity.type}`}>
              <ActivityHeroIcon type={activity.type} />
            </div>
          )}

          <div className="activity-detail-hero-copy">
            <span className="activity-detail-status-chip">{statusLabel}</span>
            <div className="activity-detail-hero-date">
              <CalendarDays size={16} />
              <span>{activity.periodText ?? '期間未設定'}</span>
            </div>
            <h2>{activity.title}</h2>
            <p>{activity.description}</p>
            <div className="activity-detail-hero-location">
              <MapPin size={18} />
              <span>{location}</span>
            </div>
          </div>
        </section>

        <div className="activity-detail-actions">
          <button
            className="activity-detail-primary-button"
            disabled={busy || app.busy}
            type="button"
            onClick={() => void handlePrimaryAction()}
          >
            {buttonIconFor(activity)}
            {busy ? '處理中' : flow.actionLabel}
          </button>
          <button
            className="activity-detail-secondary-button"
            type="button"
            onClick={() => void handleShareAction()}
          >
            <Share2 size={20} />
            分享
          </button>
        </div>

        {message && (
          <div className="success-message activity-detail-message">
            <CheckCircle2 size={18} />
            <span>{message}</span>
          </div>
        )}

        <section className="activity-detail-card" aria-label="活動詳情">
          <h3 className="activity-detail-section-title">活動詳情</h3>
          <ActivityInfoRow
            icon={<CalendarDays size={20} />}
            label="活動日期"
            value={activity.periodText ?? '期間未設定'}
          />
          <ActivityInfoRow
            icon={<Clock3 size={20} />}
            label="活動時間"
            value="依活動公告為準"
          />
          <ActivityInfoRow
            icon={<MapPin size={20} />}
            label="活動地點"
            value={location}
          />
          <ActivityInfoRow
            icon={<UserRound size={20} />}
            label="主辦單位"
            value="VeeVa Member"
          />
          <ActivityInfoRow
            icon={<Tag size={20} />}
            label="活動類型"
            value={flow.label}
          />
        </section>

        <section className="activity-detail-card">
          <div className="activity-detail-card-title-row">
            <h3>活動內容</h3>
            <ChevronDown size={18} />
          </div>
          <p>{activity.description}</p>
          <p>{activity.note ?? flow.nextStep}</p>
        </section>

        <section className="activity-detail-card">
          <h3>注意事項</h3>
          <ul className="activity-detail-notes">
            {noticeItemsFor(activity).map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </section>
      </div>
    </article>
  )
}

function ActivityInfoRow({
  icon,
  label,
  value,
  trailing,
}: {
  icon: ReactNode
  label: string
  value: string
  trailing?: ReactNode
}) {
  return (
    <div className={`activity-detail-info-row${trailing ? ' has-trailing' : ''}`}>
      <span className="activity-detail-info-icon">{icon}</span>
      <span className="activity-detail-info-label">{label}</span>
      <strong>{value}</strong>
      {trailing && (
        <span className="activity-detail-info-trailing">{trailing}</span>
      )}
    </div>
  )
}

function ActivityHeroIcon({ type }: { type: VeevaActivity['type'] }) {
  const iconProps = { size: 108, strokeWidth: 1.45 }
  if (type === 'survey') return <NotebookPen {...iconProps} />
  if (type === 'registration') return <UsersRound {...iconProps} />
  if (type === 'task') return <Microscope {...iconProps} />
  if (type === 'checkin') return <Stethoscope {...iconProps} />
  return <Megaphone {...iconProps} />
}

function buttonIconFor(activity: VeevaActivity) {
  if (activity.type === 'survey' || activity.type === 'external') {
    return <ExternalLink size={18} />
  }
  if (activity.type === 'referral') {
    return <Send size={18} />
  }
  return <Megaphone size={18} />
}

function activityStatusLabel(activity: VeevaActivity) {
  if (activity.status === 'archived' || !activity.active) return '已結束'
  if (activity.label.includes('即將')) return '即將開始'
  if (activity.label.includes('報名')) return '報名中'
  if (activity.type === 'registration') return '報名中'
  if (activity.type === 'survey') return '進行中'
  return activity.label || '進行中'
}

function fallbackLocation(activity: VeevaActivity) {
  if (activity.type === 'survey') return '線上問卷'
  if (activity.type === 'external' || activity.type === 'task') return '線上活動'
  return '活動地點待通知'
}

function noticeItemsFor(activity: VeevaActivity) {
  if (activity.type === 'survey') {
    return [
      '完成問卷後，系統會依活動規則確認紀錄。',
      '若活動包含兌換券，將依後台設定發放。',
      '如有任何問題，請聯繫主辦單位。',
    ]
  }

  if (activity.type === 'registration') {
    return [
      '本活動名額有限，請盡早完成報名。',
      '完成報名後，活動前一週將寄發行前通知。',
      '如有任何問題，請聯繫主辦單位。',
    ]
  }

  return [
    '請依活動說明完成指定流程。',
    '活動紀錄將以系統實際完成狀態為準。',
    '如有任何問題，請聯繫主辦單位。',
  ]
}

function safeDecode(value: string) {
  try {
    return decodeURIComponent(value)
  } catch {
    return value
  }
}
