import { ArrowLeft, CheckCircle2, ClipboardList, LoaderCircle } from 'lucide-react'
import { useCallback, useEffect, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import type { VeevaActivity, VeevaSurveyEngagement } from '../types/veeva'

interface PageProps {
  app: VeevaAppState
}

const SURVEY_COMPLETION_SCORE = 75
const SURVEY_MIN_VISIBLE_MS = 35_000
const SURVEY_MIN_TOTAL_MS = 45_000
const SURVEY_FAST_EXIT_MS = 15_000
const SURVEY_EVALUATION_INTERVAL_MS = 2_000

export function SurveyPage({ app }: PageProps) {
  const { activityId = '' } = useParams()
  const decodedActivityId = safeDecode(activityId)
  const activity = app.bootstrap.activities.find(
    (item) => item.id === decodedActivityId,
  )
  const completedRef = useRef(false)
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState(false)
  const [completionRecordedThisVisitFor, setCompletionRecordedThisVisitFor] =
    useState<string | null>(null)
  const surveyRecord = app.memberActivityRecords.find(
    (record) => record.activityId === activity?.id,
  )
  const backendSurveyCompleted = surveyRecord?.status === 'completed'
  const backendSurveyPendingReview = surveyRecord?.status === 'pendingReview'
  const completionRecordedThisVisit = completionRecordedThisVisitFor === activity?.id
  const surveyCompletedBeforeThisVisit =
    backendSurveyCompleted && !completionRecordedThisVisit
  const surveyPendingReviewBeforeThisVisit =
    backendSurveyPendingReview && !completionRecordedThisVisit

  useEffect(() => {
    completedRef.current = false
  }, [activity?.id])

  const handleBehaviorCompleted = useCallback(
    async (engagement: VeevaSurveyEngagement) => {
      if (!activity || completedRef.current) return
      completedRef.current = true
      setBusy(true)
      setMessage('')

      try {
        if (!app.member) {
          completedRef.current = false
          await app.login()
          return
        }
        if (
          app.memberAccessStatus !== 'ready' ||
          app.member.phoneVerified !== true
        ) {
          completedRef.current = false
          return
        }

        const { completeActivity } = await import('../services/veevaRepository')
        await completeActivity({
          activity,
          member: app.member,
          completionMethod: 'behaviorScore',
          surveyEngagement: engagement,
        })
        setCompletionRecordedThisVisitFor(activity.id)
        await app.refreshMemberData()
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
        <p>登入後再填寫問卷，系統才能記錄完成狀態並等待人工確認。</p>
        <button className="primary-button" type="button" onClick={app.login}>
          LINE 登入
        </button>
      </section>
    )
  }

  if (
    app.memberAccessStatus !== 'ready' ||
    app.member.phoneVerified !== true
  ) {
    return null
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
        <strong>
          {surveyPendingReviewBeforeThisVisit
            ? '審核中'
            : surveyCompletedBeforeThisVisit
              ? '已填寫'
              : '填寫問卷'}
        </strong>
        <span aria-hidden="true" />
      </div>

      <section className="survey-shell">
        {surveyPendingReviewBeforeThisVisit && (
          <section className="empty-state compact survey-completed-state">
            <LoaderCircle size={30} />
            <h2>審核中</h2>
          </section>
        )}

        {surveyCompletedBeforeThisVisit && (
          <section className="empty-state compact survey-completed-state">
            <CheckCircle2 size={30} />
            <h2>已填寫</h2>
          </section>
        )}

        {message && (
          <div className="success-message survey-message">
            {busy ? (
              <LoaderCircle className="spin-icon" size={18} />
            ) : (
              <CheckCircle2 size={18} />
            )}
            <span>{message}</span>
          </div>
        )}

        {!surveyPendingReviewBeforeThisVisit && !surveyCompletedBeforeThisVisit && (
          <EmbeddedSurveyFrame
            activity={activity}
            onBehaviorCompleted={handleBehaviorCompleted}
          />
        )}
      </section>
    </article>
  )
}

function EmbeddedSurveyFrame({
  activity,
  onBehaviorCompleted,
}: {
  activity: VeevaActivity
  onBehaviorCompleted: (engagement: VeevaSurveyEngagement) => void
}) {
  const iframeRef = useRef<HTMLIFrameElement>(null)
  const engagementRef = useRef(createSurveyEngagementDraft(activity))
  const completedByBehaviorRef = useRef(false)

  useEffect(() => {
    engagementRef.current = createSurveyEngagementDraft(activity)
    completedByBehaviorRef.current = false

    const recordParentPointer = () => {
      engagementRef.current.pointerCount += 1
    }
    const recordParentTouch = () => {
      engagementRef.current.touchCount += 1
    }
    const recordParentClick = () => {
      engagementRef.current.clickCount += 1
    }
    const recordParentKey = () => {
      engagementRef.current.keyCount += 1
    }
    const recordParentScroll = () => {
      const current = engagementRef.current
      current.scrollCount += 1
      current.maxParentScrollDepth = Math.max(
        current.maxParentScrollDepth,
        calculateParentScrollDepth(),
      )
    }
    const handleVisibilityChange = () => {
      applyVisibilityChange(engagementRef.current)
    }
    const handleWindowBlur = () => {
      window.setTimeout(() => {
        if (document.activeElement === iframeRef.current) {
          recordIframeFocus(engagementRef.current)
        }
      }, 60)
    }
    const evaluate = () => {
      const engagement = buildSurveyEngagement(engagementRef.current)
      if (engagement.completedByBehavior && !completedByBehaviorRef.current) {
        completedByBehaviorRef.current = true
        onBehaviorCompleted(engagement)
      }
    }

    window.addEventListener('pointerdown', recordParentPointer, {
      passive: true,
    })
    window.addEventListener('touchstart', recordParentTouch, { passive: true })
    window.addEventListener('click', recordParentClick)
    window.addEventListener('keydown', recordParentKey)
    window.addEventListener('scroll', recordParentScroll, { passive: true })
    document.addEventListener('visibilitychange', handleVisibilityChange)
    window.addEventListener('blur', handleWindowBlur)
    const evaluationTimer = window.setInterval(
      evaluate,
      SURVEY_EVALUATION_INTERVAL_MS,
    )

    return () => {
      applyVisibilityChange(engagementRef.current, true)
      window.clearInterval(evaluationTimer)
      window.removeEventListener('pointerdown', recordParentPointer)
      window.removeEventListener('touchstart', recordParentTouch)
      window.removeEventListener('click', recordParentClick)
      window.removeEventListener('keydown', recordParentKey)
      window.removeEventListener('scroll', recordParentScroll)
      document.removeEventListener('visibilitychange', handleVisibilityChange)
      window.removeEventListener('blur', handleWindowBlur)
    }
  }, [activity, onBehaviorCompleted])

  function handleIframeLoad() {
    const current = engagementRef.current
    current.iframeLoadCount += 1
    current.lastIframeLoadAtMs = Date.now()
  }

  function handleIframeFocus() {
    recordIframeFocus(engagementRef.current)
  }

  return (
    <div className="survey-frame-card">
      <iframe
        allow="clipboard-read; clipboard-write"
        className="survey-frame"
        onFocus={handleIframeFocus}
        onLoad={handleIframeLoad}
        ref={iframeRef}
        referrerPolicy="strict-origin-when-cross-origin"
        src={activity.surveyUrl}
        title="VeeVa 問卷填寫"
      />
    </div>
  )
}

interface SurveyEngagementDraft {
  activityId: string
  surveyUrl: string
  startedAtMs: number
  visibleStartedAtMs: number | null
  visibleDurationMs: number
  iframeLoadCount: number
  iframeFocusedCount: number
  lastIframeLoadAtMs: number | null
  lastIframeFocusAtMs: number | null
  pointerCount: number
  touchCount: number
  clickCount: number
  keyCount: number
  scrollCount: number
  maxParentScrollDepth: number
  hiddenCount: number
}

function createSurveyEngagementDraft(
  activity: VeevaActivity,
): SurveyEngagementDraft {
  const now = Date.now()
  const isVisible = document.visibilityState === 'visible'
  return {
    activityId: activity.id,
    surveyUrl: activity.surveyUrl ?? '',
    startedAtMs: now,
    visibleStartedAtMs: isVisible ? now : null,
    visibleDurationMs: 0,
    iframeLoadCount: 0,
    iframeFocusedCount: 0,
    lastIframeLoadAtMs: null,
    lastIframeFocusAtMs: null,
    pointerCount: 0,
    touchCount: 0,
    clickCount: 0,
    keyCount: 0,
    scrollCount: 0,
    maxParentScrollDepth: calculateParentScrollDepth(),
    hiddenCount: isVisible ? 0 : 1,
  }
}

function applyVisibilityChange(
  draft: SurveyEngagementDraft,
  forcePause = false,
) {
  const now = Date.now()
  const isVisible = document.visibilityState === 'visible' && !forcePause

  if (!isVisible) {
    if (draft.visibleStartedAtMs !== null) {
      draft.visibleDurationMs += now - draft.visibleStartedAtMs
      draft.visibleStartedAtMs = null
    }
    draft.hiddenCount += 1
    return
  }

  if (draft.visibleStartedAtMs === null) {
    draft.visibleStartedAtMs = now
  }
}

function recordIframeFocus(draft: SurveyEngagementDraft) {
  const now = Date.now()
  if (
    draft.lastIframeFocusAtMs !== null &&
    now - draft.lastIframeFocusAtMs < 800
  ) {
    return
  }
  draft.iframeFocusedCount += 1
  draft.lastIframeFocusAtMs = now
}

function buildSurveyEngagement(
  draft: SurveyEngagementDraft,
): VeevaSurveyEngagement {
  const now = Date.now()
  const totalDurationMs = Math.max(0, now - draft.startedAtMs)
  const visibleDurationMs = Math.max(
    0,
    draft.visibleDurationMs +
      (draft.visibleStartedAtMs === null ? 0 : now - draft.visibleStartedAtMs),
  )
  const parentInteractionCount =
    draft.pointerCount +
    draft.touchCount +
    draft.clickCount +
    draft.keyCount +
    draft.scrollCount
  const iframeLoaded = draft.iframeLoadCount > 0
  const fastExit = totalDurationMs < SURVEY_FAST_EXIT_MS
  const score = calculateSurveyScore({
    iframeLoaded,
    iframeFocusedCount: draft.iframeFocusedCount,
    visibleDurationMs,
    totalDurationMs,
    parentInteractionCount,
  })
  const requiredConditionsMet =
    iframeLoaded &&
    visibleDurationMs >= SURVEY_MIN_VISIBLE_MS &&
    totalDurationMs >= SURVEY_MIN_TOTAL_MS &&
    !fastExit &&
    score >= SURVEY_COMPLETION_SCORE

  return {
    activityId: draft.activityId,
    surveyUrl: draft.surveyUrl,
    score,
    completedByBehavior: requiredConditionsMet,
    startedAt: new Date(draft.startedAtMs).toISOString(),
    evaluatedAt: new Date(now).toISOString(),
    totalDurationMs: Math.round(totalDurationMs),
    visibleDurationMs: Math.round(visibleDurationMs),
    iframeLoaded,
    iframeLoadCount: draft.iframeLoadCount,
    iframeFocusedCount: draft.iframeFocusedCount,
    parentInteractionCount,
    pointerCount: draft.pointerCount,
    touchCount: draft.touchCount,
    clickCount: draft.clickCount,
    keyCount: draft.keyCount,
    scrollCount: draft.scrollCount,
    maxParentScrollDepth: draft.maxParentScrollDepth,
    hiddenCount: draft.hiddenCount,
    fastExit,
    requiredConditionsMet,
  }
}

function calculateSurveyScore(input: {
  iframeLoaded: boolean
  iframeFocusedCount: number
  visibleDurationMs: number
  totalDurationMs: number
  parentInteractionCount: number
}) {
  let score = 0
  if (input.iframeLoaded) score += 20
  if (input.iframeFocusedCount > 0) score += 10
  if (input.visibleDurationMs >= SURVEY_MIN_VISIBLE_MS) score += 20
  if (input.visibleDurationMs >= SURVEY_MIN_TOTAL_MS) score += 20
  if (input.totalDurationMs >= SURVEY_MIN_TOTAL_MS) score += 20
  if (input.totalDurationMs >= SURVEY_FAST_EXIT_MS) score += 10
  if (input.parentInteractionCount > 0) score += 10
  return Math.min(score, 100)
}

function calculateParentScrollDepth() {
  const scrollableHeight = Math.max(
    0,
    document.documentElement.scrollHeight - window.innerHeight,
  )
  if (scrollableHeight <= 0) return 0
  return Math.min(100, Math.round((window.scrollY / scrollableHeight) * 100))
}

function safeDecode(value: string) {
  try {
    return decodeURIComponent(value)
  } catch {
    return value
  }
}
