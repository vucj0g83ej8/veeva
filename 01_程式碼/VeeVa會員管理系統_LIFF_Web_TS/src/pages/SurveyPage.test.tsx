import { render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { describe, expect, it, vi } from 'vitest'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import type { VeevaActivity, VeevaMember } from '../types/veeva'
import { SurveyPage } from './SurveyPage'

const member: VeevaMember = {
  id: 'Utest-member',
  name: '未驗證會員',
  hospital: '',
  department: '',
  status: 'loggedIn',
  accountStatus: 'active',
  earnedCoupons: 0,
  invitedCount: 0,
  shareCode: 'TEST1',
  lineUserId: 'Utest-member',
  phoneVerified: false,
}

const surveyActivity: VeevaActivity = {
  id: 'survey-test',
  type: 'survey',
  label: '問卷活動',
  title: '測試問卷',
  description: '測試未驗證會員可以填寫問卷。',
  reward: '無',
  status: 'published',
  active: true,
  surveyUrl: 'https://example.com/survey',
}

function appState(): VeevaAppState {
  return {
    initializing: false,
    authenticating: false,
    memberAccessStatus: 'ready',
    memberProfileReady: true,
    officialAccountFriendshipReady: true,
    officialAccountFriend: true,
    officialAccountFriendshipSupported: true,
    newsReady: true,
    busy: false,
    member,
    bootstrap: {
      activities: [surveyActivity],
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
  } as VeevaAppState
}

describe('SurveyPage phone verification access', () => {
  it('allows a LINE member without phone verification to open the survey', () => {
    render(
      <MemoryRouter initialEntries={['/activities/survey-test/survey']}>
        <Routes>
          <Route
            path="/activities/:activityId/survey"
            element={<SurveyPage app={appState()} />}
          />
        </Routes>
      </MemoryRouter>,
    )

    const frame = screen.getByTitle('VeeVa 問卷填寫')
    expect(frame).toHaveAttribute('src', surveyActivity.surveyUrl)
    expect(screen.queryByText('手機號碼驗證')).not.toBeInTheDocument()
  })
})
