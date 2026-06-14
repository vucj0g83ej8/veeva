import { CheckCircle2, Coffee, Ticket } from 'lucide-react'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import { formatDate } from '../utils/date'

interface PageProps {
  app: VeevaAppState
}

export function CouponsPage({ app }: PageProps) {
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
    <section className="stack">
      {app.memberRewards.map((reward) => {
        const imageUrl =
          reward.rewardImageUrl ??
          app.bootstrap.rewards.find((item) => item.id === reward.rewardId)
            ?.imageUrl

        return (
          <article className="coupon-card" key={reward.id}>
            <div className="coupon-media">
              {imageUrl ? (
                <img src={imageUrl} alt={reward.rewardName} loading="lazy" />
              ) : (
                <div className="coupon-icon">
                  <Ticket size={24} />
                </div>
              )}
            </div>
            <div>
              <div className="card-topline">
                <span className="soft-tag">{statusLabel(reward.status)}</span>
                <span className="muted">期限 {formatDate(reward.expiresAt)}</span>
              </div>
              <h2>{reward.rewardName}</h2>
              <div className="detail-row">
                <CheckCircle2 size={18} />
                <span>{reward.status === 'issued' ? '可使用' : '已處理'}</span>
              </div>
            </div>
          </article>
        )
      })}
    </section>
  )
}

function statusLabel(status: string) {
  if (status === 'redeemed') return '已兌換'
  if (status === 'expired') return '已過期'
  return '可兌換'
}
