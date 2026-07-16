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

function renderShell(app: VeevaAppState) {
  render(
    <MemoryRouter initialEntries={['/activities/survey-coffee/survey']}>
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

  it('手機尚未驗證時只顯示手機驗證頁', () => {
    renderShell(
      appState({
        memberAccessStatus: 'phoneRequired',
        member: { ...member, phoneVerified: false },
      }),
    )

    expect(screen.getByText('請完成手機號碼驗證')).toBeInTheDocument()
    expect(screen.queryByTestId('protected-content')).not.toBeInTheDocument()
  })

  it('完整會員資料與手機驗證通過後才顯示原頁面', () => {
    renderShell(appState())

    expect(screen.getByTestId('protected-content')).toBeInTheDocument()
  })
})
