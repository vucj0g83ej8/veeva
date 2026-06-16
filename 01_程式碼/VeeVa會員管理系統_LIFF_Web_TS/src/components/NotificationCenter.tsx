import {
  Bell,
  CheckCircle2,
  ClipboardCheck,
  Gift,
  MessageCircle,
  X,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import type { VeevaMemberNotification } from '../types/veeva'
import { formatDateTime } from '../utils/date'

interface NotificationCenterProps {
  app: VeevaAppState
}

export function NotificationCenter({ app }: NotificationCenterProps) {
  const navigate = useNavigate()
  const [open, setOpen] = useState(false)
  const unreadNotifications = useMemo(
    () =>
      app.notifications
        .filter((item) => !item.readAt)
        .sort((a, b) => {
          const aTime = a.createdAt?.getTime() ?? 0
          const bTime = b.createdAt?.getTime() ?? 0
          return bTime - aTime
        }),
    [app.notifications],
  )
  const unreadCount = unreadNotifications.length
  const visibleNotifications = unreadNotifications.slice(0, 3)
  const badgeText = unreadCount > 3 ? '3+' : `${unreadCount}`

  const handleClose = useCallback(() => {
    if (visibleNotifications.length > 0) {
      void app.markNotificationsRead(
        visibleNotifications.map((notification) => notification.id),
      )
    }
    setOpen(false)
  }, [app, visibleNotifications])

  useEffect(() => {
    if (!open) return undefined
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') handleClose()
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [handleClose, open])

  const handleOpen = () => {
    setOpen(true)
    void app.refreshNotifications()
  }

  const handleNotificationClick = (notification: VeevaMemberNotification) => {
    if (notification.actionPath?.startsWith('/')) {
      handleClose()
      navigate(notification.actionPath)
    }
  }

  return (
    <>
      <button
        className={`icon-button notification-trigger${
          unreadCount > 0 ? ' has-notifications' : ''
        }`}
        type="button"
        aria-label={unreadCount > 0 ? `通知，${unreadCount} 則未讀` : '通知'}
        onClick={handleOpen}
      >
        <Bell size={20} />
        {unreadCount > 0 && (
          <span className="notification-badge" aria-hidden="true">
            {badgeText}
          </span>
        )}
      </button>

      {open && (
        <div
          className="notification-overlay"
          role="dialog"
          aria-modal="true"
          aria-labelledby="notification-title"
          onMouseDown={handleClose}
        >
          <div
            className="notification-sheet"
            onMouseDown={(event) => event.stopPropagation()}
          >
            <header className="notification-header">
              <div>
                <p className="eyebrow">System Message</p>
                <h2 id="notification-title">系統訊息</h2>
              </div>
              <button
                className="notification-close"
                type="button"
                aria-label="關閉系統訊息"
                onClick={handleClose}
              >
                <X size={22} />
              </button>
            </header>

            <div className="notification-list">
              {visibleNotifications.length === 0 ? (
                <section className="notification-empty">
                  <MessageCircle size={28} />
                  <h3>目前沒有未讀訊息</h3>
                </section>
              ) : (
                visibleNotifications.map((notification) => (
                  <button
                    className="notification-item"
                    key={notification.id}
                    type="button"
                    onClick={() => handleNotificationClick(notification)}
                  >
                    <span className="notification-item-icon">
                      {iconForNotification(notification)}
                    </span>
                    <span className="notification-item-copy">
                      <strong>{notification.title}</strong>
                      <span>{notification.body}</span>
                      <time>{formatDateTime(notification.createdAt)}</time>
                    </span>
                  </button>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </>
  )
}

function iconForNotification(notification: VeevaMemberNotification) {
  if (notification.type === 'rewardIssued') return <Gift size={20} />
  if (notification.type === 'activityCompleted') return <ClipboardCheck size={20} />
  return <CheckCircle2 size={20} />
}
