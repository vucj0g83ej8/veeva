import { ArrowLeft, CheckCircle2, ClipboardList, LoaderCircle } from 'lucide-react'
import { useCallback, useEffect, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import type { VeevaActivity } from '../types/veeva'

interface PageProps {
  app: VeevaAppState
}

export function SurveyPage({ app }: PageProps) {
  const { activityId = '' } = useParams()
  const decodedActivityId = safeDecode(activityId)
  const activity = app.bootstrap.activities.find(
    (item) => item.id === decodedActivityId,
  )
  const completedRef = useRef(false)
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState(false)

  const handleSurveyCompleted = useCallback(
    async (source: string) => {
      if (!activity || completedRef.current) return
      completedRef.current = true
      setBusy(true)
      setMessage('已偵測到問卷完成，正在寫入活動紀錄...')

      try {
        if (!app.member) {
          await app.login()
          setMessage('請先完成 LINE 登入，登入後會保留問卷完成狀態。')
          return
        }

        const { completeActivity } = await import('../services/veevaRepository')
        const result = await completeActivity({
          activity,
          member: app.member,
        })
        await app.refreshMemberData()

        const memberRewardText = result.memberRewardIssued
          ? '已發放你的活動完成兌換券。'
          : result.memberRewardReason === 'alreadyIssued'
            ? '你的活動完成兌換券先前已發放。'
            : '此活動目前沒有可發放的完成兌換券。'
        const referrerRewardText = result.referrerRewardIssued
          ? '邀請者加碼兌換券也已發放。'
          : ''

        setMessage(
          [`問卷完成已記錄。`, memberRewardText, referrerRewardText]
            .filter(Boolean)
            .join(' '),
        )
        console.info('VeeVa survey completed by', source)
      } catch (error) {
        completedRef.current = false
        setMessage(
          error instanceof Error
            ? error.message
            : '問卷完成紀錄寫入失敗，請稍後再試。',
        )
      } finally {
        setBusy(false)
      }
    },
    [activity, app],
  )

  if (!activity) {
    return (
      <section className="empty-state">
        <ClipboardList size={30} />
        <h2>找不到問卷活動</h2>
        <p>這個活動可能已下架或尚未發布。</p>
        <Link className="secondary-button" to="/activities">
          <ArrowLeft size={18} />
          回活動列表
        </Link>
      </section>
    )
  }

  if (!activity.surveyUrl) {
    return (
      <section className="empty-state">
        <ClipboardList size={30} />
        <h2>尚未設定問卷</h2>
        <p>請等待主辦單位更新問卷連結。</p>
        <Link className="secondary-button" to={`/activities/${activity.id}`}>
          <ArrowLeft size={18} />
          回活動資訊
        </Link>
      </section>
    )
  }

  if (!app.member) {
    return (
      <section className="empty-state">
        <ClipboardList size={30} />
        <h2>請先登入 LINE</h2>
        <p>登入後再填寫問卷，系統才能記錄完成狀態並發放兌換券。</p>
        <button className="primary-button" type="button" onClick={app.login}>
          LINE 登入
        </button>
      </section>
    )
  }

  return (
    <article className="survey-page">
      <div className="activity-detail-nav">
        <Link
          aria-label="回活動資訊"
          className="activity-detail-back"
          to={`/activities/${activity.id}`}
        >
          <ArrowLeft size={24} />
        </Link>
        <strong>填寫問卷</strong>
        <span aria-hidden="true" />
      </div>

      <section className="survey-shell">
        <div className="survey-title-row">
          <div>
            <span className="soft-tag">問卷活動</span>
            <h2>{activity.title}</h2>
          </div>
          {busy ? <LoaderCircle className="spin-icon" size={22} /> : null}
        </div>

        {message && (
          <div className="success-message survey-message">
            <CheckCircle2 size={18} />
            <span>{message}</span>
          </div>
        )}

        <EmbeddedSurveyFrame
          activity={activity}
          onCompleted={(source) => void handleSurveyCompleted(source)}
        />
      </section>
    </article>
  )
}

function EmbeddedSurveyFrame({
  activity,
  onCompleted,
}: {
  activity: VeevaActivity
  onCompleted: (source: string) => void
}) {
  const seenInitialLoadRef = useRef(false)
  const canCompleteFromReloadRef = useRef(false)

  useEffect(() => {
    canCompleteFromReloadRef.current = false
    seenInitialLoadRef.current = false
    const reloadTimer = window.setTimeout(() => {
      canCompleteFromReloadRef.current = true
    }, 8000)

    const handleSubmittedEvent = () => {
      onCompleted('OneTrustWebFormSubmitted')
    }

    const handleMessage = (event: MessageEvent) => {
      if (!isTrustedOneTrustMessage(event, activity.surveyUrl ?? '')) {
        return
      }
      const messageText = stringifyMessageData(event.data)
      try {
        ;(window as Window & { veevaLastOneTrustMessage?: string })
          .veevaLastOneTrustMessage = messageText
      } catch {
        // Debug-only helper; completion detection should continue.
      }
      if (looksLikeOneTrustSubmission(messageText)) {
        onCompleted('OneTrustPostMessage')
      }
    }

    window.addEventListener(
      'OneTrustWebFormSubmitted',
      handleSubmittedEvent as EventListener,
    )
    window.addEventListener('message', handleMessage)
    return () => {
      window.clearTimeout(reloadTimer)
      window.removeEventListener(
        'OneTrustWebFormSubmitted',
        handleSubmittedEvent as EventListener,
      )
      window.removeEventListener('message', handleMessage)
    }
  }, [activity.surveyUrl, onCompleted])

  function handleIframeLoad() {
    if (!seenInitialLoadRef.current) {
      seenInitialLoadRef.current = true
      return
    }
    if (canCompleteFromReloadRef.current) {
      onCompleted('OneTrustIframeReload')
    }
  }

  return (
    <div className="survey-frame-card">
      <iframe
        allow="clipboard-read; clipboard-write"
        className="survey-frame"
        onLoad={handleIframeLoad}
        referrerPolicy="strict-origin-when-cross-origin"
        src={activity.surveyUrl}
        title="VeeVa 問卷填寫"
      />
    </div>
  )
}

function isTrustedOneTrustMessage(event: MessageEvent, formUrl: string) {
  return isTrustedOneTrustOrigin(event.origin, formUrl)
}

function isTrustedOneTrustOrigin(origin: string, formUrl: string) {
  try {
    const originUrl = new URL(origin)
    const surveyUrl = new URL(formUrl)
    if (originUrl.protocol !== 'https:') return false
    const host = originUrl.hostname.toLowerCase()
    const surveyHost = surveyUrl.hostname.toLowerCase()
    return (
      host === surveyHost ||
      host === 'onetrust.com' ||
      host.endsWith('.onetrust.com')
    )
  } catch {
    return false
  }
}

function looksLikeOneTrustSubmission(messageText: string) {
  const normalized = messageText.toLowerCase()
  if (!normalized) return false

  const hasSubmitSignal =
    normalized.includes('submit') ||
    normalized.includes('submitted') ||
    normalized.includes('submission') ||
    normalized.includes('requestsubmission') ||
    normalized.includes('request_submission') ||
    normalized.includes('request id') ||
    normalized.includes('requestid') ||
    normalized.includes('webformsubmitted') ||
    normalized.includes('formsubmitted')

  if (!hasSubmitSignal) return false

  return (
    normalized.includes('onetrust') ||
    normalized.includes('webform') ||
    normalized.includes('privacyportal') ||
    normalized.includes('request') ||
    normalized.includes('form')
  )
}

function stringifyMessageData(data: unknown) {
  if (data == null) return ''
  if (typeof data === 'string') return data
  if (typeof data === 'number' || typeof data === 'boolean') return String(data)
  try {
    return JSON.stringify(data)
  } catch {
    return String(data)
  }
}

function safeDecode(value: string) {
  try {
    return decodeURIComponent(value)
  } catch {
    return value
  }
}
