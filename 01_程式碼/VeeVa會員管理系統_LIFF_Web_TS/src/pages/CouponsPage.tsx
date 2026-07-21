import {
  ArrowLeft,
  Bell,
  CalendarDays,
  CheckCircle2,
  ChevronRight,
  Coffee,
  Copy,
  ExternalLink,
  Info,
  Store,
  Ticket,
} from 'lucide-react'
import { useEffect, useState } from 'react'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import type { VeevaMemberReward, VeevaReward } from '../types/veeva'
import { formatDate } from '../utils/date'

interface PageProps {
  app: VeevaAppState
}

export function CouponsPage({ app }: PageProps) {
  const [selectedReward, setSelectedReward] = useState<VeevaMemberReward | null>(
    null,
  )
  const [handledDeepLinkRewardId, setHandledDeepLinkRewardId] = useState<
    string | null
  >(null)
  useEffect(() => {
    if (!selectedReward) return undefined
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setSelectedReward(null)
      }
    }
    document.body.classList.add('coupon-detail-open')
    window.addEventListener('keydown', onKeyDown)
    return () => {
      document.body.classList.remove('coupon-detail-open')
      window.removeEventListener('keydown', onKeyDown)
    }
  }, [selectedReward])

  useEffect(() => {
    const rewardId = new URLSearchParams(window.location.search).get('reward')
    if (!rewardId || handledDeepLinkRewardId === rewardId) return
    const reward = app.memberRewards.find((item) => item.id === rewardId)
    if (!reward) return
    setSelectedReward(reward)
    setHandledDeepLinkRewardId(rewardId)
  }, [app.memberRewards, handledDeepLinkRewardId])

  if (!app.member) {
    return (
      <section className="empty-state">
        <Ticket size={30} />
        <h2>請先登入 LINE</h2>
        <button className="primary-button" type="button" onClick={app.login}>
          LINE 登入
        </button>
      </section>
    )
  }

  if (app.memberRewards.length === 0) {
    return (
      <section className="empty-state">
        <Coffee size={30} />
        <h2>目前沒有可用兌換券</h2>
        <p>完成活動後會發放到你的帳戶。</p>
      </section>
    )
  }

  return (
    <>
      <section className="stack">
        {app.memberRewards.map((reward) => {
          const rewardDefinition = findRewardDefinition(
            app.bootstrap.rewards,
            reward.rewardId,
          )
          const imageUrl = reward.rewardImageUrl ?? rewardDefinition?.imageUrl

          return (
            <button
              className="coupon-card coupon-card-button"
              key={reward.id}
              type="button"
              onClick={() => setSelectedReward(reward)}
            >
              <div className="coupon-media">
                {imageUrl ? (
                  <img src={imageUrl} alt={reward.rewardName} loading="lazy" />
                ) : (
                  <div className="coupon-icon">
                    <Ticket size={24} />
                  </div>
                )}
              </div>
              <div className="coupon-card-copy">
                <div className="card-topline">
                  <span className="soft-tag">{statusLabel(reward.status)}</span>
                  <span className="muted">
                    期限 {formatDate(reward.expiresAt)}
                  </span>
                </div>
                <h2>{reward.rewardName}</h2>
                <div className="detail-row">
                  <CheckCircle2 size={18} />
                  <span>
                    {reward.status === 'issued'
                      ? '可使用'
                      : statusLabel(reward.status)}
                  </span>
                </div>
              </div>
              <ChevronRight className="coupon-card-chevron" size={20} />
            </button>
          )
        })}
      </section>

      {selectedReward ? (
        <CouponDetailDialog
          imageUrl={
            selectedReward.rewardImageUrl ??
            findRewardDefinition(app.bootstrap.rewards, selectedReward.rewardId)
              ?.imageUrl
          }
          reward={selectedReward}
          rewardDefinition={findRewardDefinition(
            app.bootstrap.rewards,
            selectedReward.rewardId,
          )}
          onClose={() => setSelectedReward(null)}
        />
      ) : null}
    </>
  )
}

interface CouponDetailDialogProps {
  reward: VeevaMemberReward
  rewardDefinition?: VeevaReward
  imageUrl?: string
  onClose: () => void
}

function CouponDetailDialog({
  reward,
  rewardDefinition,
  imageUrl,
  onClose,
}: CouponDetailDialogProps) {
  const [embeddedRedemptionUrl, setEmbeddedRedemptionUrl] = useState<
    string | null
  >(null)
  const [confirmingRedemptionUrl, setConfirmingRedemptionUrl] = useState<
    string | null
  >(null)
  const [iframeLoaded, setIframeLoaded] = useState(false)
  const [verificationCodeCopied, setVerificationCodeCopied] = useState(false)
  const [verificationCodeError, setVerificationCodeError] = useState<
    string | null
  >(null)
  const isUsable = reward.status === 'issued'
  const requiresVerificationCode =
    rewardDefinition?.requiresVerificationCode ??
    reward.requiresVerificationCode ??
    false
  const verificationCode = reward.verificationCode?.trim() ?? ''
  const canUseReward =
    !requiresVerificationCode ||
    (verificationCode.length > 0 && verificationCodeCopied)
  const storeText = eligibleStoreText(reward.rewardName)
  const instructions = couponInstructions(reward.rewardName, rewardDefinition)
  const closeEmbeddedRedemption = () => {
    setEmbeddedRedemptionUrl(null)
    setIframeLoaded(false)
  }
  const copyVerificationCode = async () => {
    if (!verificationCode) {
      setVerificationCodeError('此兌換券尚未設定驗證碼')
      return
    }
    setVerificationCodeError(null)
    try {
      await copyTextToClipboard(verificationCode)
      setVerificationCodeCopied(true)
    } catch {
      setVerificationCodeError('無法複製驗證碼，請稍後再試')
    }
  }
  const confirmUseCoupon = () => {
    if (!confirmingRedemptionUrl) return
    setIframeLoaded(false)
    setEmbeddedRedemptionUrl(confirmingRedemptionUrl)
    setConfirmingRedemptionUrl(null)
  }

  return (
    <div
      aria-modal="true"
      className="coupon-detail-overlay"
      role="dialog"
      aria-labelledby="coupon-detail-title"
    >
      <div className="coupon-detail-shell">
        <header className="coupon-detail-header">
          <button
            className="coupon-detail-icon-button"
            type="button"
            aria-label="返回兌換券列表"
            onClick={onClose}
          >
            <ArrowLeft size={28} />
          </button>
          <h2 id="coupon-detail-title">兌換券詳情</h2>
          <button
            className="coupon-detail-bell"
            type="button"
            aria-label="通知"
          >
            <Bell size={22} />
          </button>
        </header>

        <article className="coupon-detail-panel">
          <div className="coupon-detail-image-frame">
            {imageUrl ? (
              <img src={imageUrl} alt={reward.rewardName} loading="lazy" />
            ) : (
              <div className="coupon-detail-image-empty">
                <Ticket size={36} />
              </div>
            )}
          </div>

          <span className="coupon-detail-status">{statusLabel(reward.status)}</span>
          <h3>{reward.rewardName}</h3>
          <div className="coupon-detail-meta">
            <span>
              <CalendarDays size={18} />
              期限 {formatDate(reward.expiresAt)}
            </span>
            <i aria-hidden="true" />
            <span>
              <CheckCircle2 size={18} />
              {isUsable ? '可使用' : statusLabel(reward.status)}
            </span>
          </div>

          <hr />

          <section className="coupon-detail-section">
            <h4>
              <Info size={18} />
              兌換說明
            </h4>
            <ul>
              {instructions.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </section>

          <section className="coupon-detail-store">
            <div>
              <h4>
                <Store size={18} />
                適用門市
              </h4>
              <p>{storeText}</p>
            </div>
            <ChevronRight size={22} aria-hidden="true" />
          </section>

          {reward.redemptionUrl && isUsable ? (
            <>
              {requiresVerificationCode ? (
                <div className="coupon-verification-code-actions">
                  <button
                    className={`coupon-verification-code-button${
                      verificationCodeCopied ? ' copied' : ''
                    }`}
                    type="button"
                    disabled={!verificationCode}
                    onClick={() => void copyVerificationCode()}
                  >
                    {verificationCodeCopied ? (
                      <CheckCircle2 size={21} />
                    ) : (
                      <Copy size={21} />
                    )}
                    {verificationCodeCopied
                      ? '已複製驗證碼'
                      : verificationCode
                        ? '複製驗證碼'
                        : '尚未設定驗證碼'}
                  </button>
                  {verificationCodeError ? (
                    <p className="coupon-verification-code-error">
                      {verificationCodeError}
                    </p>
                  ) : null}
                </div>
              ) : null}
              <button
                className={`coupon-detail-use-button${
                  canUseReward ? '' : ' disabled'
                }`}
                type="button"
                disabled={!canUseReward}
                onClick={() => {
                  if (!canUseReward) return
                  setConfirmingRedemptionUrl(reward.redemptionUrl ?? null)
                }}
              >
                <Ticket size={22} />
                {canUseReward ? '使用優惠券' : '請先複製驗證碼'}
              </button>
            </>
          ) : (
            <button className="coupon-detail-use-button disabled" type="button" disabled>
              <Ticket size={22} />
              {isUsable ? '尚未取得兌換連結' : statusLabel(reward.status)}
            </button>
          )}
          <p className="coupon-detail-warning">
            請於門市結帳時出示優惠券給店員掃描
          </p>
        </article>
      </div>

      {confirmingRedemptionUrl ? (
        <div
          aria-modal="true"
          className="coupon-use-confirm-backdrop"
          role="dialog"
          aria-labelledby="coupon-use-confirm-title"
        >
          <div className="coupon-use-confirm-dialog">
            <span className="coupon-use-confirm-icon">
              <Ticket size={26} />
            </span>
            <h3 id="coupon-use-confirm-title">開啟優惠券</h3>
            <p>確認後將開啟兌換券頁面。</p>
            <div className="coupon-use-confirm-actions">
              <button
                className="coupon-use-confirm-cancel"
                type="button"
                onClick={() => setConfirmingRedemptionUrl(null)}
              >
                取消
              </button>
              <button
                className="coupon-use-confirm-submit"
                type="button"
                onClick={confirmUseCoupon}
              >
                確認開啟
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {embeddedRedemptionUrl ? (
        <div
          aria-modal="true"
          className="coupon-redemption-overlay"
          role="dialog"
          aria-label="使用優惠券"
        >
          <header className="coupon-redemption-header">
            <button
              className="coupon-detail-icon-button"
              type="button"
              aria-label="返回兌換券詳情"
              onClick={closeEmbeddedRedemption}
            >
              <ArrowLeft size={28} />
            </button>
            <h2>使用優惠券</h2>
            <a
              className="coupon-redemption-external"
              href={embeddedRedemptionUrl}
              target="_blank"
              rel="noreferrer"
              aria-label="另開兌換網頁"
            >
              <ExternalLink size={20} />
            </a>
          </header>
          <div className="coupon-redemption-frame-wrap">
            {!iframeLoaded ? (
              <div className="coupon-redemption-loading">
                <span className="loading-dot" />
                <span>正在開啟兌換頁</span>
              </div>
            ) : null}
            <iframe
              className="coupon-redemption-frame"
              src={embeddedRedemptionUrl}
              title={`${reward.rewardName} 兌換頁`}
              loading="eager"
              sandbox="allow-forms allow-popups allow-same-origin allow-scripts allow-top-navigation-by-user-activation"
              allow="clipboard-read; clipboard-write"
              onLoad={() => setIframeLoaded(true)}
            />
          </div>
        </div>
      ) : null}
    </div>
  )
}

function statusLabel(status: string) {
  if (status === 'pending') return '待確認'
  if (status === 'redeemed') return '已使用'
  if (status === 'expired') return '已過期'
  return '可兌換'
}

function findRewardDefinition(rewards: VeevaReward[], rewardId: string) {
  return rewards.find((item) => item.id === rewardId)
}

function eligibleStoreText(rewardName: string) {
  if (/星巴克|starbucks/i.test(rewardName)) {
    return '台灣地區星巴克門市（不含車道服務、外送服務及部分特殊門市）'
  }
  return '依兌換券連結、活動頁面或店家公告為準'
}

function couponInstructions(
  rewardName: string,
  rewardDefinition?: VeevaReward,
) {
  const firstLine = rewardDefinition?.description?.trim()
    ? rewardDefinition.description.trim()
    : `本券可兌換 ${rewardName}。`
  return [
    firstLine,
    '使用前請主動出示本券給門市人員掃描使用。',
    '本券不可兌換現金、不可找零，且不得與其他優惠合併使用。',
    '本券若有遺失、破損或影印無效，恕不補發。',
    '主辦單位保留活動修改、變更及終止之權利。',
  ]
}

async function copyTextToClipboard(text: string) {
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(text)
      return
    } catch {
      // LINE WebView can reject the modern clipboard API; use the fallback.
    }
  }

  const textarea = document.createElement('textarea')
  textarea.value = text
  textarea.setAttribute('readonly', '')
  textarea.style.position = 'fixed'
  textarea.style.opacity = '0'
  document.body.appendChild(textarea)
  textarea.select()
  const copied = document.execCommand('copy')
  textarea.remove()
  if (!copied) throw new Error('copy failed')
}
