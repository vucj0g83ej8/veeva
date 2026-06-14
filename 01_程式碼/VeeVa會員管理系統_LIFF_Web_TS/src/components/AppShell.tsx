import { Bell, CalendarDays, Newspaper, Ticket, UserRound } from 'lucide-react'
import type { PropsWithChildren } from 'react'
import { NavLink, useLocation } from 'react-router-dom'
import type { VeevaAppState } from '../hooks/useVeevaApp'

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
  const title = titleForPath(location.pathname)
  const mainClassName = location.pathname.startsWith('/news/')
    ? 'app-main article-main'
    : 'app-main'

  return (
    <div className="app-shell">
      <header className="app-header">
        <div>
          <p className="eyebrow">VeeVa Member</p>
          <h1>{title}</h1>
        </div>
        <button className="icon-button" type="button" aria-label="通知">
          <Bell size={20} />
        </button>
      </header>

      <main className={mainClassName}>
        {app.initializing ? (
          <div className="loading-panel">
            <span className="loading-dot" />
            <span>{app.authenticating ? '正在前往 LINE 登入' : '正在確認登入'}</span>
          </div>
        ) : (
          children
        )}
      </main>

      <nav className="bottom-nav" aria-label="主要導覽">
        {navItems.map((item) => {
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

function titleForPath(pathname: string) {
  if (pathname.startsWith('/news')) return '最新資訊'
  if (pathname.startsWith('/coupons')) return '兌換券'
  if (pathname.startsWith('/member') || pathname.startsWith('/r/')) return '會員'
  return '活動'
}
