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
import {
  captureReferralCodeFromLocation,
  referralCodeFromLocation,
  referralCodeFromUrl,
  readPendingReferralCode,
  rememberPendingReferralCode,
  shareCodeFromId,
} from '../utils/shareCode'
import {
  clearCachedMember,
  readCachedMember,
  rememberCachedMember,
} from '../utils/localMemberCache'
import { getCachedOfficialAccountFriendship } from '../utils/officialAccountFriendshipCache'

interface AppState {
  initializing: boolean
  authenticating: boolean
  memberProfileReady: boolean
  officialAccountFriendshipReady: boolean
  officialAccountFriend: boolean
  officialAccountFriendshipSupported: boolean
  officialAccountFriendshipError?: string
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

const liffInitTimeoutMs = 10_000
const bootstrapTimeoutMs = 5_000

export function useVeevaApp() {
  const initializedRef = useRef(false)
  const [state, setState] = useState<AppState>(() => {
    const cachedMember = readCachedMember()
    const cachedFriendship = cachedMember
      ? getCachedOfficialAccountFriendship(cachedMember.id)
      : undefined

    return {
      initializing: !cachedMember,
      authenticating: false,
      memberProfileReady: Boolean(cachedMember),
      officialAccountFriendshipReady: cachedFriendship?.friend === true,
      officialAccountFriend: cachedFriendship?.friend === true,
      officialAccountFriendshipSupported: cachedFriendship?.supported ?? true,
      busy: false,
      bootstrap: emptyBootstrap,
      member: cachedMember,
      memberActivityRecords: [],
      memberRewards: [],
      notifications: [],
      referrals: [],
      referralCode: captureReferralCodeFromLocation(),
    }
  })

  const refreshMemberDetails = useCallback(async (member: VeevaMember) => {
    const {
      loadMemberActivityRecords,
      loadMemberNotifications,
      loadMemberRewards,
      loadReferralRecords,
    } = await import('../services/veevaRepository')

    const memberActivityRecords = await loadMemberActivityRecords(member.id).catch(
      () => [],
    )
    setState((current) => ({
      ...current,
      memberActivityRecords,
    }))

    void Promise.all([
      loadMemberRewards(member.id).catch(() => []),
      loadReferralRecords(member.id).catch(() => []),
      loadMemberNotifications(member.id).catch(() => []),
    ]).then(([memberRewards, referrals, notifications]) => {
      setState((current) => ({
        ...current,
        memberRewards,
        notifications,
        referrals,
      }))
    })
  }, [])

  const refreshMemberNotifications = useCallback(async (member: VeevaMember) => {
    const { loadMemberNotifications } = await import('../services/veevaRepository')
    const notifications = await loadMemberNotifications(member.id).catch(() => [])
    setState((current) => ({
      ...current,
      notifications,
    }))
  }, [])

  const refreshOfficialAccountFriendship = useCallback(async (memberId?: string) => {
    const cachedFriendship = getCachedOfficialAccountFriendship(memberId)
    setState((current) => ({
      ...current,
      officialAccountFriendshipReady: cachedFriendship?.friend === true,
      officialAccountFriend: cachedFriendship?.friend === true,
      officialAccountFriendshipSupported: cachedFriendship?.supported ?? true,
      officialAccountFriendshipError: undefined,
    }))
    const { getOfficialAccountFriendship } = await import('../services/liff')
    const result = await getOfficialAccountFriendship()
    setState((current) => ({
      ...current,
      officialAccountFriendshipReady: true,
      officialAccountFriend: result.friend,
      officialAccountFriendshipSupported: result.supported,
      officialAccountFriendshipError: result.error,
    }))
    return result
  }, [])

  const requestOfficialAccountFriendship = useCallback(async () => {
    const referralCode =
      referralCodeFromLocation() ?? state.referralCode ?? readPendingReferralCode()
    if (referralCode) {
      rememberPendingReferralCode(referralCode, { overwrite: true })
    }
    const { requestOfficialAccountFriendship: requestFriendship } = await import(
      '../services/liff'
    )
    await requestFriendship()
  }, [state.referralCode])

  const initialize = useCallback(async () => {
    const cachedMember = readCachedMember()
    const cachedFriendship = cachedMember
      ? getCachedOfficialAccountFriendship(cachedMember.id)
      : undefined
    setState((current) => ({
      ...current,
      initializing: !cachedMember,
      authenticating: false,
      memberProfileReady: Boolean(cachedMember),
      officialAccountFriendshipReady: cachedFriendship?.friend === true,
      officialAccountFriend: cachedFriendship?.friend === true,
      officialAccountFriendshipSupported: cachedFriendship?.supported ?? true,
      officialAccountFriendshipError: undefined,
      member: cachedMember ?? current.member,
      error: undefined,
    }))
    try {
      const liffApi = await import('../services/liff')
      const repositoryPromise = import('../services/veevaRepository')
      const liffSessionPromise = liffApi.initializeLiff()
      const bootstrapPromise = repositoryPromise.then((repository) =>
        repository.loadInitialBootstrap().catch(() => emptyBootstrap),
      )
      void bootstrapPromise.then((bootstrap) => {
        setState((current) => ({
          ...current,
          bootstrap,
        }))
      })
      void bootstrapPromise.finally(() => {
        window.setTimeout(() => {
          void repositoryPromise
            .then((repository) => repository.loadDeferredBootstrapContent())
            .then(({ news, rewards }) => {
              setState((current) => ({
                ...current,
                bootstrap: {
                  ...current.bootstrap,
                  news,
                  rewards,
                },
              }))
            })
            .catch(() => undefined)
        }, 300)
      })
      const liffSession = await withTimeout(liffSessionPromise, liffInitTimeoutMs, {
        initialized: false,
        loggedIn: false,
        inClient: false,
        error: 'LINE 初始化逾時，請重新整理後再試。',
      })

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
          memberProfileReady: false,
          officialAccountFriendshipReady: false,
        }))
        await liffApi.loginWithLine()
        return
      }

      const repository = await repositoryPromise
      const bootstrap = await withTimeout(
        bootstrapPromise,
        bootstrapTimeoutMs,
        emptyBootstrap,
      )
      const pendingLoginUrl = liffApi.getPendingLoginRedirectUrl()
      const referralCode =
        referralCodeFromLocation() ??
        state.referralCode ??
        (pendingLoginUrl ? referralCodeFromUrl(pendingLoginUrl) : undefined) ??
        readPendingReferralCode()
      if (referralCode) {
        rememberPendingReferralCode(referralCode)
      }

      const member = memberFromLiffSession(liffSession)
      const restoreUrl = member
        ? liffApi.consumePendingLoginRedirectUrl()
        : undefined

      setState((current) => ({
        ...current,
        initializing: false,
        authenticating: false,
        memberProfileReady: !member,
        officialAccountFriendshipReady: !member,
        officialAccountFriend: false,
        officialAccountFriendshipError: undefined,
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
        void refreshOfficialAccountFriendship(member.id)
        void repository
          .upsertLineMember({
            profile: liffSession.profile!,
            lineIdToken: liffSession.idToken,
            referralCode,
          })
          .then(async (updatedMember) => {
            rememberCachedMember(updatedMember)
            setState((current) => ({
              ...current,
              member: updatedMember,
              memberProfileReady: true,
            }))
            await refreshMemberDetails(updatedMember)
          })
          .catch((error) => {
            setState((current) => ({
              ...current,
              memberProfileReady: true,
              error: error instanceof Error ? error.message : String(error),
            }))
          })
      }
      restoreUrlAfterLogin(restoreUrl)
    } catch (error) {
      setState((current) => ({
        ...current,
        initializing: false,
        authenticating: false,
        memberProfileReady: true,
        error: error instanceof Error ? error.message : String(error),
      }))
    }
  }, [refreshMemberDetails, refreshOfficialAccountFriendship, state.referralCode])

  useEffect(() => {
    if (initializedRef.current) return
    initializedRef.current = true
    void initialize()
  }, [initialize])

  useEffect(() => {
    let disposed = false
    let unsubscribe: (() => void) | undefined

    void import('../services/veevaRepository').then((repository) => {
      if (disposed) return
      unsubscribe = repository.subscribeActivities(
        (activities) => {
          setState((current) => ({
            ...current,
            bootstrap: {
              ...current.bootstrap,
              activities,
            },
          }))
        },
        (error) => {
          setState((current) => ({
            ...current,
            error: error.message,
          }))
        },
      )
    })

    return () => {
      disposed = true
      unsubscribe?.()
    }
  }, [])

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
        referralCode:
          referralCodeFromLocation() ?? state.referralCode ?? readPendingReferralCode(),
      })
      rememberCachedMember(member)
      setState((current) => ({
        ...current,
        busy: false,
        memberProfileReady: true,
        officialAccountFriendshipReady: false,
        officialAccountFriend: false,
        liffSession,
        member,
        memberActivityRecords: [],
        memberRewards: [],
        notifications: [],
        referrals: [],
      }))
      await refreshOfficialAccountFriendship(member.id)
      await refreshMemberDetails(member)
    } catch (error) {
      setState((current) => ({
        ...current,
        busy: false,
        error: error instanceof Error ? error.message : String(error),
      }))
    }
  }, [refreshMemberDetails, refreshOfficialAccountFriendship, state.referralCode])

  const logout = useCallback(async () => {
    clearCachedMember()
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
        rememberCachedMember(member)
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

  const completePhoneVerification = useCallback(
    async (input: { phoneNumber: string; firebasePhoneUid: string }) => {
      if (!state.member) {
        throw new Error('請先登入會員')
      }
      setState((current) => ({ ...current, busy: true, error: undefined }))
      try {
        const { updateMemberPhoneVerification } = await import(
          '../services/veevaRepository'
        )
        const member = await updateMemberPhoneVerification({
          memberId: state.member.id,
          phoneNumber: input.phoneNumber,
          firebasePhoneUid: input.firebasePhoneUid,
          referralCode:
            referralCodeFromLocation() ??
            state.referralCode ??
            readPendingReferralCode(),
        })
        rememberCachedMember(member)
        setState((current) => ({
          ...current,
          busy: false,
          member,
          memberProfileReady: true,
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
      refreshOfficialAccountFriendship,
      requestOfficialAccountFriendship,
      shareInvite,
      markNotificationsRead,
      completePhoneVerification,
      updateMemberProfile,
    }),
    [
      disabled,
      completePhoneVerification,
      initialize,
      login,
      logout,
      markNotificationsRead,
      refreshMemberData,
      refreshNotifications,
      refreshOfficialAccountFriendship,
      requestOfficialAccountFriendship,
      shareInvite,
      state,
      updateMemberProfile,
    ],
  )
}

export type VeevaAppState = ReturnType<typeof useVeevaApp>

function memberFromLiffSession(session: LiffSession): VeevaMember | undefined {
  const profile = session.profile
  if (!session.loggedIn || !profile) return undefined

  return {
    id: profile.userId,
    name: profile.displayName || 'LINE 會員',
    hospital: '',
    department: '',
    status: 'loggedIn',
    accountStatus: 'active',
    earnedCoupons: 0,
    invitedCount: 0,
    shareCode: shareCodeFromId(profile.userId),
    lineUserId: profile.userId,
    avatarUrl: profile.pictureUrl,
    email: profile.email,
    lineStatusMessage: profile.statusMessage,
    lastLineLoginAt: new Date(),
  }
}

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

function withTimeout<T>(promise: Promise<T>, timeoutMs: number, fallback: T) {
  let timeoutId: number | undefined
  const timeout = new Promise<T>((resolve) => {
    timeoutId = window.setTimeout(() => resolve(fallback), timeoutMs)
  })
  return Promise.race([promise, timeout]).finally(() => {
    if (timeoutId !== undefined) {
      window.clearTimeout(timeoutId)
    }
  })
}
