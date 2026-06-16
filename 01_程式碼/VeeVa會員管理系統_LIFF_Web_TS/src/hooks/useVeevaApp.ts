import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type {
  BootstrapData,
  LiffSession,
  VeevaActivityRegistration,
  VeevaMember,
  VeevaMemberNotification,
  VeevaMemberReward,
  VeevaReferralRecord,
} from '../types/veeva'
import { referralCodeFromLocation, referralCodeFromUrl } from '../utils/shareCode'

interface AppState {
  initializing: boolean
  authenticating: boolean
  busy: boolean
  error?: string
  liffSession?: LiffSession
  member?: VeevaMember
  bootstrap: BootstrapData
  memberActivityRecords: VeevaActivityRegistration[]
  memberRewards: VeevaMemberReward[]
  notifications: VeevaMemberNotification[]
  referrals: VeevaReferralRecord[]
  referralCode?: string
}

const emptyBootstrap: BootstrapData = {
  activities: [],
  news: [],
  rewards: [],
  clientSettings: {
    newsEnabled: true,
  },
}

export function useVeevaApp() {
  const initializedRef = useRef(false)
  const [state, setState] = useState<AppState>({
    initializing: true,
    authenticating: false,
    busy: false,
    bootstrap: emptyBootstrap,
    memberActivityRecords: [],
    memberRewards: [],
    notifications: [],
    referrals: [],
    referralCode: referralCodeFromLocation(),
  })

  const refreshMemberDetails = useCallback(async (member: VeevaMember) => {
    const {
      loadMemberActivityRecords,
      loadMemberNotifications,
      loadMemberRewards,
      loadReferralRecords,
    } = await import('../services/veevaRepository')
    const [memberActivityRecords, memberRewards, referrals, notifications] =
      await Promise.all([
        loadMemberActivityRecords(member.id).catch(() => []),
        loadMemberRewards(member.id).catch(() => []),
        loadReferralRecords(member.id).catch(() => []),
        loadMemberNotifications(member.id).catch(() => []),
      ])
    setState((current) => ({
      ...current,
      memberActivityRecords,
      memberRewards,
      notifications,
      referrals,
    }))
  }, [])

  const refreshMemberNotifications = useCallback(async (member: VeevaMember) => {
    const { loadMemberNotifications } = await import('../services/veevaRepository')
    const notifications = await loadMemberNotifications(member.id).catch(() => [])
    setState((current) => ({
      ...current,
      notifications,
    }))
  }, [])

  const initialize = useCallback(async () => {
    setState((current) => ({
      ...current,
      initializing: true,
      authenticating: false,
      error: undefined,
    }))
    try {
      const liffApi = await import('../services/liff')
      const liffSession = await liffApi.initializeLiff()

      if (
        !liffSession.loggedIn &&
        !liffSession.error &&
        liffApi.shouldAutoLineLogin()
      ) {
        setState((current) => ({
          ...current,
          initializing: true,
          authenticating: true,
          liffSession,
        }))
        await liffApi.loginWithLine()
        return
      }

      const repository = await import('../services/veevaRepository')
      const bootstrap = await repository.loadBootstrap().catch(() => emptyBootstrap)
      const pendingLoginUrl = liffApi.getPendingLoginRedirectUrl()
      const referralCode =
        state.referralCode ??
        (pendingLoginUrl ? referralCodeFromUrl(pendingLoginUrl) : undefined)

      let member: VeevaMember | undefined
      if (liffSession.loggedIn && liffSession.profile) {
        member = await repository.upsertLineMember({
          profile: liffSession.profile,
          lineIdToken: liffSession.idToken,
          referralCode,
        })
      }
      const restoreUrl = member
        ? liffApi.consumePendingLoginRedirectUrl()
        : undefined

      setState((current) => ({
        ...current,
        initializing: false,
        authenticating: false,
        bootstrap,
        liffSession,
        member,
        memberActivityRecords: member ? current.memberActivityRecords : [],
        memberRewards: member ? current.memberRewards : [],
        notifications: member ? current.notifications : [],
        referrals: member ? current.referrals : [],
        error: liffSession.error,
        referralCode,
      }))

      if (member) {
        await refreshMemberDetails(member)
      }
      restoreUrlAfterLogin(restoreUrl)
    } catch (error) {
      setState((current) => ({
        ...current,
        initializing: false,
        authenticating: false,
        error: error instanceof Error ? error.message : String(error),
      }))
    }
  }, [refreshMemberDetails, state.referralCode])

  useEffect(() => {
    if (initializedRef.current) return
    initializedRef.current = true
    void initialize()
  }, [initialize])

  const login = useCallback(async () => {
    setState((current) => ({ ...current, busy: true, error: undefined }))
    try {
      const [liffApi, repository] = await Promise.all([
        import('../services/liff'),
        import('../services/veevaRepository'),
      ])
      const liffSession = await liffApi.loginWithLine()
      if (!liffSession.loggedIn || !liffSession.profile) {
        setState((current) => ({ ...current, busy: false, liffSession }))
        return
      }

      const member = await repository.upsertLineMember({
        profile: liffSession.profile,
        lineIdToken: liffSession.idToken,
        referralCode: state.referralCode,
      })
      setState((current) => ({
        ...current,
        busy: false,
        liffSession,
        member,
        memberActivityRecords: [],
        memberRewards: [],
        notifications: [],
        referrals: [],
      }))
      await refreshMemberDetails(member)
    } catch (error) {
      setState((current) => ({
        ...current,
        busy: false,
        error: error instanceof Error ? error.message : String(error),
      }))
    }
  }, [refreshMemberDetails, state.referralCode])

  const logout = useCallback(async () => {
    const { logoutLine } = await import('../services/liff')
    logoutLine()
  }, [])

  const refreshMemberData = useCallback(async () => {
    if (!state.member) return
    await refreshMemberDetails(state.member)
  }, [refreshMemberDetails, state.member])

  const refreshNotifications = useCallback(async () => {
    if (!state.member) return
    await refreshMemberNotifications(state.member)
  }, [refreshMemberNotifications, state.member])

  const markNotificationsRead = useCallback(
    async (notificationIds?: string[]) => {
      if (!state.member) return
      const targetIds =
        notificationIds ??
        state.notifications.filter((item) => !item.readAt).map((item) => item.id)
      if (targetIds.length === 0) return

      const readAt = new Date()
      setState((current) => ({
        ...current,
        notifications: current.notifications.map((item) =>
          targetIds.includes(item.id) ? { ...item, readAt } : item,
        ),
      }))

      const { markMemberNotificationsRead } = await import(
        '../services/veevaRepository'
      )
      await markMemberNotificationsRead({
        memberId: state.member.id,
        notificationIds: targetIds,
      })
    },
    [state.member, state.notifications],
  )

  useEffect(() => {
    if (!state.member) return undefined
    const timer = window.setInterval(() => {
      void refreshMemberNotifications(state.member!)
    }, 60_000)
    return () => window.clearInterval(timer)
  }, [refreshMemberNotifications, state.member])

  const updateMemberProfile = useCallback(
    async (input: { name: string; email: string }) => {
      if (!state.member) {
        throw new Error('請先登入會員')
      }
      setState((current) => ({ ...current, busy: true, error: undefined }))
      try {
        const { updateMemberProfile: updateProfile } = await import(
          '../services/veevaRepository'
        )
        const member = await updateProfile({
          memberId: state.member.id,
          name: input.name,
          email: input.email,
        })
        setState((current) => ({
          ...current,
          busy: false,
          member,
        }))
        await refreshMemberDetails(member)
        return member
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error)
        setState((current) => ({
          ...current,
          busy: false,
          error: message,
        }))
        throw new Error(message, { cause: error })
      }
    },
    [refreshMemberDetails, state.member],
  )

  const shareInvite = useCallback(async () => {
    if (!state.member) {
      await login()
      return
    }
    setState((current) => ({ ...current, busy: true, error: undefined }))
    try {
      const { shareInviteCard } = await import('../services/liff')
      await shareInviteCard(state.member.name, state.member.shareCode)
      setState((current) => ({ ...current, busy: false }))
    } catch (error) {
      setState((current) => ({
        ...current,
        busy: false,
        error: error instanceof Error ? error.message : String(error),
      }))
    }
  }, [login, state.member])

  const disabled = state.member?.accountStatus === 'disabled'

  return useMemo(
    () => ({
      ...state,
      disabled,
      login,
      logout,
      refresh: initialize,
      refreshMemberData,
      refreshNotifications,
      shareInvite,
      markNotificationsRead,
      updateMemberProfile,
    }),
    [
      disabled,
      initialize,
      login,
      logout,
      markNotificationsRead,
      refreshMemberData,
      refreshNotifications,
      shareInvite,
      state,
      updateMemberProfile,
    ],
  )
}

export type VeevaAppState = ReturnType<typeof useVeevaApp>

function restoreUrlAfterLogin(url?: string) {
  if (!url) return
  try {
    const restoreUrl = new URL(url)
    if (restoreUrl.origin !== window.location.origin) return
    const restorePath = `${restoreUrl.pathname}${restoreUrl.search}${restoreUrl.hash}`
    const currentPath = `${window.location.pathname}${window.location.search}${window.location.hash}`
    if (restorePath === currentPath) return
    window.history.replaceState(window.history.state, '', restorePath)
    window.dispatchEvent(new PopStateEvent('popstate', { state: window.history.state }))
  } catch {
    return
  }
}
