import { CalendarDays, Newspaper, Ticket, UserRound } from 'lucide-react'
import type { PropsWithChildren } from 'react'
import { NavLink, useLocation } from 'react-router-dom'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import { NotificationCenter } from './NotificationCenter'
import { PhoneVerificationGate } from './PhoneVerificationGate'

const navItems = [
  { to: '/activities', label: '活動', icon: CalendarDays },
  { to: '/news', label: '最新資訊', icon: Newspaper },
  { to: '/coupons', label: '兌換券', icon: Ticket },
  { to: '/member', label: '會員', icon: UserRound },
]

interface AppShellProps extends PropsWithChildren {
  app: VeevaAppState
}

export function AppShell({ app, children }: AppShellProps) {
  const location = useLocation()
  const newsEnabled = app.bootstrap.clientSettings.newsEnabled
  const visibleNavItems = newsEnabled
    ? navItems
    : navItems.filter((item) => item.to !== '/news')
  const title = titleForPath(location.pathname, newsEnabled)
  const mainClassName = location.pathname.startsWith('/news/')
    ? 'app-main article-main'
    : 'app-main'
  const requiresPhoneVerification = Boolean(
    app.member &&
      app.memberProfileReady &&
      !app.disabled &&
      !app.member.phoneVerified,
  )

  return (
    <div className="app-shell">
      <header className="app-header">
        <div className="app-title-block">
          <img
            className="brand-logo"
            src="/assets/brand/veeva-logo.png"
            alt="Veeva"
          />
          <h1>{title}</h1>
        </div>
        <NotificationCenter app={app} />
      </header>

      <main className={mainClassName}>
        {app.initializing ? (
          <div className="loading-panel">
            <span className="loading-dot" />
            <span>{app.authenticating ? '正在前往 LINE 登入' : '正在確認登入'}</span>
          </div>
        ) : requiresPhoneVerification ? (
          <PhoneVerificationGate app={app} />
        ) : (
          children
        )}
      </main>

      <nav
        className="bottom-nav"
        aria-label="主要導覽"
        style={{ gridTemplateColumns: `repeat(${visibleNavItems.length}, 1fr)` }}
      >
        {visibleNavItems.map((item) => {
          const Icon = item.icon
          return (
            <NavLink
              className={({ isActive }) => (isActive ? 'active' : '')}
              key={item.to}
              to={item.to}
            >
              <Icon size={21} />
              <span>{item.label}</span>
            </NavLink>
          )
        })}
      </nav>
    </div>
  )
}

function titleForPath(pathname: string, newsEnabled: boolean) {
  if (pathname.startsWith('/news') && newsEnabled) return '最新資訊'
  if (pathname.startsWith('/coupons')) return '兌換券'
  if (pathname.startsWith('/member') || pathname.startsWith('/r/')) return '會員中心'
  return '活動'
}
