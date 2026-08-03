import liff from '@line/liff'
import type { LiffProfile, LiffSession, VeevaActivity } from '../types/veeva'
import {
  liffId,
  liffUrlForPath,
} from '../utils/inviteUrl'
import {
  captureReferralCodeFromLocation,
  readPendingReferralCode,
  referralCodeFromLocation,
  rememberPendingReferralCode,
} from '../utils/shareCode'
import {
  getCachedOfficialAccountFriendship as readCachedOfficialAccountFriendship,
  rememberOfficialAccountFriendship,
} from '../utils/officialAccountFriendshipCache'
export { getCachedOfficialAccountFriendship } from '../utils/officialAccountFriendshipCache'

const beforeLoginUrlKey = 'veeva_liff_before_login_url'
const loginTokenKey = 'veeva_line_login_token'
const loginTokenExpiresAtKey = 'veeva_line_login_token_expires_at'
const idTokenKey = 'veeva_line_id_token'
const idTokenExpiresAtKey = 'veeva_line_id_token_expires_at'
const lineUserIdKey = 'veeva_line_user_id'
const loginInfoKey = 'veeva_line_login_info'
const tokenLifetimeMs = 60 * 60 * 1000
const friendshipCheckTimeoutMs = 4_500
const friendshipRequestTimeoutMs = 7_000
const publicAppUrl =
  import.meta.env.VITE_PUBLIC_LIFF_URL?.replace(/\/$/, '') ||
  'https://veeva.web.app'
const inviteImageUrl = `${publicAppUrl}/assets/share/veeva-711-survey-gift-v2.png`
const officialAccountId =
  import.meta.env.VITE_LINE_OFFICIAL_ACCOUNT_ID?.trim() || '@veevaconnect'
export const lineCardShareUnsupportedError = 'LINE_CARD_SHARE_UNSUPPORTED'

let initPromise: Promise<LiffSession> | undefined

export interface StoredLineLoginInfo {
  lineUserId: string
  displayName: string
  pictureUrl?: string
  email?: string
  loginProvider: 'line'
  lastLoginAt: string
  expiresAt: string
  idTokenExpiresAt?: string
}

export async function initializeLiff(): Promise<LiffSession> {
  if (!liffId.trim()) {
    return {
      initialized: false,
      loggedIn: false,
      inClient: false,
      error: '尚未設定 LIFF ID',
    }
  }

  if (!initPromise) {
    initPromise = initLiff()
  }

  return initPromise
}

export async function loginWithLine() {
  captureReferralCodeFromLocation()
  storeBeforeLoginUrl(window.location.href)
  await initializeLiff()
  if (liff.isLoggedIn()) {
    return readLiffSession()
  }
  liff.login({ redirectUri: loginRedirectUri() })
  return {
    initialized: true,
    loggedIn: false,
    inClient: liff.isInClient(),
  } satisfies LiffSession
}

export function shouldAutoLineLogin() {
  if (new URLSearchParams(window.location.search).get('skipAutoLogin') === '1') {
    return false
  }
  return import.meta.env.VITE_AUTO_LINE_LOGIN === 'true'
}

export function getPendingLoginRedirectUrl() {
  return safeRead(() => sessionStorage.getItem(beforeLoginUrlKey)) ?? undefined
}

export function consumePendingLoginRedirectUrl() {
  const url = getPendingLoginRedirectUrl()
  sessionStorage.removeItem(beforeLoginUrlKey)
  return isSameOriginUrl(url) ? url : undefined
}

export function getStoredLineLoginInfo() {
  try {
    const raw = localStorage.getItem(loginInfoKey)
    if (!raw) return undefined
    const info = JSON.parse(raw) as StoredLineLoginInfo
    if (!info.expiresAt || new Date(info.expiresAt).getTime() <= Date.now()) {
      clearStoredLoginToken()
      return undefined
    }
    return info
  } catch {
    clearStoredLoginToken()
    return undefined
  }
}

export interface OfficialAccountFriendshipResult {
  friend: boolean
  supported: boolean
  error?: string
}

export function officialAccountAddUrl() {
  const normalizedId = officialAccountId.startsWith('@')
    ? officialAccountId
    : `@${officialAccountId}`
  return `https://line.me/R/ti/p/${normalizedId}`
}

export function openUrlInApp(url: string) {
  const targetUrl = new URL(url, window.location.href)
  if (!['http:', 'https:'].includes(targetUrl.protocol)) {
    throw new Error('無法開啟此連結。')
  }

  if (safeRead(() => liff.isInClient())) {
    try {
      liff.openWindow({
        url: targetUrl.toString(),
        external: false,
      })
      return
    } catch {
      // Fall through to same-window navigation when LINE cannot open its browser.
    }
  }

  window.location.assign(targetUrl.toString())
}

export async function getOfficialAccountFriendship(): Promise<OfficialAccountFriendshipResult> {
  const session = await initializeLiff()
  if (!session.loggedIn) {
    return {
      friend: false,
      supported: true,
      error: 'not_logged_in',
    }
  }

  try {
    const getFriendship = (
      liff as unknown as {
        getFriendship?: () => Promise<{ friendFlag?: boolean }>
      }
    ).getFriendship

    if (typeof getFriendship !== 'function') {
      return {
        friend: false,
        supported: false,
        error: 'friendship_api_unavailable',
      }
    }

    const result = await withTimeout(
      getFriendship.call(liff),
      friendshipCheckTimeoutMs,
      () => ({ friendFlag: false, timedOut: true }),
    )
    if ('timedOut' in result) {
      const cached = readCachedOfficialAccountFriendship(session.profile?.userId)
      if (cached?.friend) return cached
      return {
        friend: false,
        supported: false,
        error: 'official_account_friendship_timeout',
      }
    }
    const friendshipResult = {
      friend: result.friendFlag === true,
      supported: true,
    }
    rememberOfficialAccountFriendship(friendshipResult, session.profile?.userId)
    return friendshipResult
  } catch (error) {
    const cached = readCachedOfficialAccountFriendship(session.profile?.userId)
    if (cached?.friend) return cached
    return {
      friend: false,
      supported: false,
      error: error instanceof Error ? error.message : String(error),
    }
  }
}

export async function requestOfficialAccountFriendship() {
  preserveReferralCodeForExternalLineFlow()
  await initializeLiff()

  const requestFriendship = (
    liff as unknown as {
      requestFriendship?: () => Promise<void>
    }
  ).requestFriendship

  if (typeof requestFriendship === 'function') {
    try {
      const result = await withTimeout(
        requestFriendship.call(liff).then(() => 'completed' as const),
        friendshipRequestTimeoutMs,
        () => 'timedOut' as const,
      )
      if (result === 'completed') {
        return
      }
    } catch {
      // Some LIFF/OA combinations do not support requestFriendship. The add-friend URL remains the fallback.
    }
  }

  const url = officialAccountAddUrl()
  if (safeRead(() => liff.isInClient())) {
    liff.openWindow({
      url,
      external: false,
    })
    return
  }
  window.location.href = url
}

export function logoutLine() {
  if (liff.isLoggedIn()) {
    liff.logout()
  }
  clearStoredLoginToken()
  window.location.reload()
}

export async function shareInviteCard(memberName: string, shareCode: string) {
  const session = await initializeLiff()
  if (!session.loggedIn) {
    throw new Error('請先使用 LINE 登入後再分享邀請。')
  }
  if (!liff.isApiAvailable('shareTargetPicker')) {
    throw new Error('此 LINE 環境尚未支援分享功能。')
  }

  const code = encodeURIComponent(shareCode)
  const inviteUrl = liffUrlForPath(`/activities/survey-coffee?ref=${code}`)
  await liff.shareTargetPicker([
    {
      type: 'flex',
      altText: `${memberName} 邀請你填寫問卷，審核通過送 7-ELEVEN 虛擬商品卡`,
      contents: {
        type: 'bubble',
        size: 'giga',
        hero: {
          type: 'image',
          url: inviteImageUrl,
          size: 'full',
          aspectRatio: '1:1',
          aspectMode: 'cover',
          action: {
            type: 'uri',
            label: '立即加入',
            uri: inviteUrl,
          },
        },
        body: {
          type: 'box',
          layout: 'vertical',
          spacing: 'lg',
          paddingAll: '24px',
          backgroundColor: '#FFF8F1',
          contents: [
            {
              type: 'text',
              text: '填問卷送 7-ELEVEN 虛擬商品卡',
              weight: 'bold',
              size: 'xl',
              wrap: true,
              color: '#D95700',
            },
            {
              type: 'text',
              text: `${memberName} 邀請你加入 VeeVa 會員並填寫線上問卷，審核通過即可領取 7-ELEVEN 虛擬商品卡。`,
              wrap: true,
              color: '#3A281C',
              size: 'md',
              lineSpacing: '8px',
            },
            {
              type: 'text',
              text: '加入帳號、填寫問卷，審核後領取好禮！',
              wrap: true,
              size: 'md',
              weight: 'bold',
              color: '#E56A00',
            },
          ],
        },
        footer: {
          type: 'box',
          layout: 'vertical',
          paddingTop: '0px',
          paddingBottom: '24px',
          paddingStart: '24px',
          paddingEnd: '24px',
          backgroundColor: '#FFF8F1',
          contents: [
            {
              type: 'button',
              style: 'primary',
              height: 'md',
              color: '#E56400',
              action: {
                type: 'uri',
                label: '加入官網，填寫問卷',
                uri: officialAccountAddUrl(),
              },
            },
          ],
        },
      },
    },
  ])
}

export async function shareActivityCard(
  activity: VeevaActivity,
  memberShareCode?: string,
) {
  const session = await initializeLiff()
  if (!session.inClient) {
    throw new Error(lineCardShareUnsupportedError)
  }
  if (!session.loggedIn) {
    throw new Error('請先使用 LINE 登入後再分享活動。')
  }
  if (!liff.isApiAvailable('shareTargetPicker')) {
    throw new Error(lineCardShareUnsupportedError)
  }

  const actionLabel = activityShareButtonLabel(activity)
  const activitySearch = new URLSearchParams({
    shareTemplate: 'activity-card-v3',
  })
  const cleanShareCode = memberShareCode?.trim()
  if (cleanShareCode) {
    activitySearch.set('ref', cleanShareCode)
  }
  const activityUrl = liffUrlForPath(
    `/activities/${encodeURIComponent(activity.id)}?${activitySearch.toString()}`,
  )
  const imageUrl = activityShareImageUrl(activity)
  const result = await liff.shareTargetPicker([
    {
      type: 'flex',
      altText: `分享活動：${activity.title}`,
      contents: {
        type: 'bubble',
        size: 'mega',
        hero: {
          type: 'image',
          url: imageUrl,
          size: 'full',
          aspectRatio: '1:1',
          aspectMode: 'cover',
          action: {
            type: 'uri',
            label: actionLabel,
            uri: activityUrl,
          },
        },
        body: {
          type: 'box',
          layout: 'vertical',
          spacing: 'lg',
          paddingAll: '24px',
          backgroundColor: '#FFFFFF',
          contents: [
            {
              type: 'text',
              text: truncateForLine(activity.title, 46),
              wrap: true,
              weight: 'bold',
              size: 'xl',
              color: '#5B321E',
            },
          ],
        },
        footer: {
          type: 'box',
          layout: 'vertical',
          paddingTop: '0px',
          paddingBottom: '24px',
          paddingStart: '24px',
          paddingEnd: '24px',
          backgroundColor: '#FFFFFF',
          contents: [
            {
              type: 'button',
              style: 'primary',
              height: 'md',
              color: '#98531F',
              action: {
                type: 'uri',
                label: actionLabel,
                uri: activityUrl,
              },
            },
          ],
        },
      },
    },
  ])
  return Boolean(result)
}

function activityShareImageUrl(activity: VeevaActivity) {
  const configuredImageUrl = lineCompatibleActivityImageUrl(activity)
  if (configuredImageUrl) {
    return configuredImageUrl
  }

  const key = [
    activity.id,
    activity.type,
    activity.title,
    activity.description,
  ]
    .join(' ')
    .toLowerCase()
  if (key.includes('research') || key.includes('clinical')) {
    return absoluteAssetUrl('/assets/share/activity-research.png')
  }
  if (
    key.includes('education') ||
    key.includes('workshop') ||
    key.includes('hospital') ||
    key.includes('checkin')
  ) {
    return absoluteAssetUrl('/assets/share/activity-education.png')
  }
  if (key.includes('safety')) {
    return absoluteAssetUrl('/assets/share/activity-safety.png')
  }
  if (
    key.includes('webinar') ||
    key.includes('cme') ||
    activity.type === 'survey' ||
    activity.type === 'task' ||
    activity.type === 'external'
  ) {
    return absoluteAssetUrl('/assets/share/activity-webinar.png')
  }
  return absoluteAssetUrl('/assets/share/activity-seminar.png')
}

function lineCompatibleActivityImageUrl(activity: VeevaActivity) {
  const candidates = [activity.shareImageUrl, activity.imageUrl]
  for (const candidate of candidates) {
    if (isLineShareImageUrl(candidate)) {
      return candidate!.trim()
    }
  }
  return undefined
}

function isLineShareImageUrl(value?: string) {
  const text = value?.trim()
  if (!text) return false
  try {
    const url = new URL(text)
    if (url.protocol !== 'https:') return false
    const path = decodeURIComponent(url.pathname).toLowerCase()
    if (path.endsWith('.webp') || path.endsWith('.gif')) return false
    if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) {
      return true
    }
    return true
  } catch {
    return false
  }
}

function absoluteAssetUrl(path: string) {
  return new URL(path, window.location.origin).toString()
}

function activityShareButtonLabel(activity: VeevaActivity) {
  if (activity.type === 'survey') return '立即填寫問卷'
  if (activity.type === 'registration') return '立即報名'
  if (activity.type === 'referral') return '立即邀請好友'
  return '立即查看活動'
}

function truncateForLine(value: string, maxLength: number) {
  const text = value.trim()
  if (text.length <= maxLength) return text
  return `${text.slice(0, maxLength - 1)}…`
}

async function initLiff(): Promise<LiffSession> {
  try {
    await liff.init({
      liffId,
      withLoginOnExternalBrowser: false,
    })
    return readLiffSession()
  } catch (error) {
    return {
      initialized: false,
      loggedIn: false,
      inClient: false,
      error: error instanceof Error ? error.message : String(error),
    }
  }
}

async function readLiffSession(): Promise<LiffSession> {
  const loggedIn = liff.isLoggedIn()
  let profile: LiffProfile | undefined
  let idToken: string | undefined
  let accessToken: string | undefined

  if (loggedIn) {
    const lineProfile = await liff.getProfile()
    const decoded = liff.getDecodedIDToken()
    profile = {
      userId: lineProfile.userId,
      displayName: lineProfile.displayName,
      pictureUrl: lineProfile.pictureUrl ?? undefined,
      statusMessage: lineProfile.statusMessage ?? undefined,
      email: decoded?.email,
    }
    idToken = liff.getIDToken() ?? undefined
    accessToken = liff.getAccessToken() ?? undefined
    storeLoginToken({
      idToken,
      accessToken,
      lineUserId: profile.userId,
      profile,
    })
  } else {
    clearStoredLoginToken()
  }

  return {
    initialized: true,
    loggedIn,
    inClient: liff.isInClient(),
    idToken,
    accessToken,
    idTokenExpiresAt: idToken ? idTokenExpiresAt(idToken) : undefined,
    profile,
    os: safeRead(() => liff.getOS()),
    lineVersion: safeRead(() => liff.getLineVersion()) ?? undefined,
    liffVersion: safeRead(() => liff.getVersion()),
  }
}

function storeLoginToken(input: {
  idToken?: string
  accessToken?: string
  lineUserId?: string
  profile?: LiffProfile
}) {
  const now = Date.now()
  const idTokenExpires = input.idToken
    ? idTokenExpiresAt(input.idToken)
    : undefined
  const token =
    input.idToken && (!idTokenExpires || idTokenExpires.getTime() > now)
      ? input.idToken
      : input.accessToken
  const expiresAt =
    token === input.idToken && idTokenExpires
      ? idTokenExpires
      : new Date(now + tokenLifetimeMs)

  if (!token) {
    clearStoredLoginToken()
    return
  }

  localStorage.setItem(loginTokenKey, token)
  localStorage.setItem(loginTokenExpiresAtKey, expiresAt.toISOString())
  if (token === input.idToken) {
    localStorage.setItem(idTokenKey, token)
    localStorage.setItem(idTokenExpiresAtKey, expiresAt.toISOString())
  } else {
    localStorage.removeItem(idTokenKey)
    localStorage.removeItem(idTokenExpiresAtKey)
  }
  if (input.lineUserId) {
    localStorage.setItem(lineUserIdKey, input.lineUserId)
  }
  if (input.profile) {
    localStorage.setItem(
      loginInfoKey,
      JSON.stringify({
        lineUserId: input.profile.userId,
        displayName: input.profile.displayName,
        pictureUrl: input.profile.pictureUrl,
        email: input.profile.email,
        loginProvider: 'line',
        lastLoginAt: new Date(now).toISOString(),
        expiresAt: expiresAt.toISOString(),
        idTokenExpiresAt: idTokenExpires?.toISOString(),
      } satisfies StoredLineLoginInfo),
    )
  }
}

function clearStoredLoginToken() {
  localStorage.removeItem(loginTokenKey)
  localStorage.removeItem(loginTokenExpiresAtKey)
  localStorage.removeItem(idTokenKey)
  localStorage.removeItem(idTokenExpiresAtKey)
  localStorage.removeItem(lineUserIdKey)
  localStorage.removeItem(loginInfoKey)
}

function idTokenExpiresAt(token: string) {
  try {
    const payload = JSON.parse(
      atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')),
    )
    if (typeof payload.exp === 'number') {
      return new Date(payload.exp * 1000)
    }
  } catch {
    return undefined
  }
  return undefined
}

function safeRead<T>(callback: () => T) {
  try {
    return callback()
  } catch {
    return undefined
  }
}

function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  fallback: () => T,
) {
  let timeoutId: number | undefined
  const timeout = new Promise<T>((resolve) => {
    timeoutId = window.setTimeout(() => resolve(fallback()), timeoutMs)
  })
  return Promise.race([promise, timeout]).finally(() => {
    if (timeoutId !== undefined) {
      window.clearTimeout(timeoutId)
    }
  })
}

function loginRedirectUri() {
  const publicLiffUrl = import.meta.env.VITE_PUBLIC_LIFF_URL
  if (publicLiffUrl) {
    return `${publicLiffUrl.replace(/\/$/, '')}/`
  }
  return `${window.location.origin}/`
}

function storeBeforeLoginUrl(url: string) {
  if (isSameOriginUrl(url)) {
    sessionStorage.setItem(beforeLoginUrlKey, url)
  }
}

function preserveReferralCodeForExternalLineFlow() {
  const code = referralCodeFromLocation() ?? readPendingReferralCode()
  if (code) {
    rememberPendingReferralCode(code, { overwrite: true })
  }
}

function isSameOriginUrl(url?: string) {
  if (!url) return false
  try {
    return new URL(url).origin === window.location.origin
  } catch {
    return false
  }
}
