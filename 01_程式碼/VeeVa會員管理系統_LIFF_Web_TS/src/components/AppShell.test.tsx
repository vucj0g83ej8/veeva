import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { describe, expect, it, vi } from 'vitest'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import type { VeevaMember } from '../types/veeva'
import { AppShell } from './AppShell'

const member: VeevaMember = {
  id: 'Utest-member',
  name: '測試會員',
  hospital: '',
  department: '',
  status: 'loggedIn',
  accountStatus: 'active',
  earnedCoupons: 0,
  invitedCount: 0,
  shareCode: 'TEST1',
  lineUserId: 'Utest-member',
}

function appState(
  overrides: Partial<VeevaAppState> = {},
): VeevaAppState {
  return {
    initializing: false,
    authenticating: false,
    memberAccessStatus: 'ready',
    memberProfileReady: true,
    officialAccountFriendshipReady: true,
    officialAccountFriend: true,
    officialAccountFriendshipSupported: true,
    busy: false,
    member: { ...member, phoneVerified: true },
    bootstrap: {
      activities: [],
      news: [],
      rewards: [],
      clientSettings: { newsEnabled: true },
    },
    memberActivityRecords: [],
    memberRewards: [],
    notifications: [],
    referrals: [],
    disabled: false,
    login: vi.fn(),
    logout: vi.fn(),
    refresh: vi.fn(),
    refreshMemberData: vi.fn(),
    refreshNotifications: vi.fn(),
    refreshOfficialAccountFriendship: vi.fn(),
    requestOfficialAccountFriendship: vi.fn(),
    shareInvite: vi.fn(),
    markNotificationsRead: vi.fn(),
    completePhoneVerification: vi.fn(),
    updateMemberProfile: vi.fn(),
    ...overrides,
  } as VeevaAppState
}

function renderShell(
  app: VeevaAppState,
  path = '/activities/survey-coffee/survey',
) {
  render(
    <MemoryRouter initialEntries={[path]}>
      <AppShell app={app}>
        <div data-testid="protected-content">問卷內容</div>
      </AppShell>
    </MemoryRouter>,
  )
}

describe('AppShell member access gate', () => {
  it('完整會員資料尚未確認時不掛載問卷內容', () => {
    renderShell(appState({ memberAccessStatus: 'checking' }))

    expect(screen.getByText('正在確認會員資料')).toBeInTheDocument()
    expect(screen.queryByTestId('protected-content')).not.toBeInTheDocument()
  })

  it('手機尚未驗證時仍可顯示原頁面', () => {
    renderShell(
      appState({
        memberAccessStatus: 'ready',
        member: { ...member, phoneVerified: false },
      }),
    )

    expect(screen.getByTestId('protected-content')).toBeInTheDocument()
    expect(screen.queryByText('手機號碼驗證')).not.toBeInTheDocument()
  })

  it('未加入官方帳號時不檢查也不攔截原頁面', () => {
    renderShell(
      appState({
        officialAccountFriendshipReady: false,
        officialAccountFriend: false,
      }),
    )

    expect(screen.getByTestId('protected-content')).toBeInTheDocument()
    expect(screen.queryByText('請先加入官方帳號')).not.toBeInTheDocument()
    expect(screen.queryByText('正在確認官方帳號加入狀態')).not.toBeInTheDocument()
  })

  it('完整會員資料確認後顯示原頁面', () => {
    renderShell(appState())

    expect(screen.getByTestId('protected-content')).toBeInTheDocument()
  })

  it('最新資訊入口與頁面標題顯示為常見問題', () => {
    renderShell(appState(), '/news')

    expect(screen.getAllByText('常見問題')).toHaveLength(2)
    expect(screen.queryByText('最新資訊')).not.toBeInTheDocument()
  })
})
