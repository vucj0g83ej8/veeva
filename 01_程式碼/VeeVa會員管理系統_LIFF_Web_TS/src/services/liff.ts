import liff from '@line/liff'
import type { LiffProfile, LiffSession, VeevaActivity } from '../types/veeva'
import {
  inviteUrlForShareCode,
  liffId,
  liffUrlForPath,
} from '../utils/inviteUrl'

const beforeLoginUrlKey = 'veeva_liff_before_login_url'
const loginTokenKey = 'veeva_line_login_token'
const loginTokenExpiresAtKey = 'veeva_line_login_token_expires_at'
const idTokenKey = 'veeva_line_id_token'
const idTokenExpiresAtKey = 'veeva_line_id_token_expires_at'
const lineUserIdKey = 'veeva_line_user_id'
const loginInfoKey = 'veeva_line_login_info'
const tokenLifetimeMs = 60 * 60 * 1000
const inviteImageUrl =
  'https://vevva.web.app/assets/share/coffee-member-gift-v1.png'
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

  const inviteUrl = inviteUrlForShareCode(shareCode)
  await liff.shareTargetPicker([
    {
      type: 'flex',
      altText: `${memberName} 邀請你加入會員，加入送咖啡`,
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
          backgroundColor: '#FFFFFF',
          contents: [
            {
              type: 'text',
              text: '加入會員送咖啡',
              weight: 'bold',
              size: 'xxl',
              color: '#5B321E',
            },
            {
              type: 'text',
              text: `${memberName} 邀請你加入 VeeVa 會員，完成加入即可獲得咖啡好禮。`,
              wrap: true,
              color: '#6B4A38',
              size: 'md',
              lineSpacing: '8px',
            },
            {
              type: 'text',
              text: '簡單加入，好禮立即送！',
              wrap: true,
              size: 'lg',
              weight: 'bold',
              color: '#98531F',
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
                label: '立即加入領咖啡',
                uri: inviteUrl,
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
        size: 'giga',
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
              size: 'xxl',
              color: '#5B321E',
            },
            {
              type: 'text',
              text: activityShareIntro(activity),
              wrap: true,
              size: 'md',
              color: '#6B4A38',
              lineSpacing: '8px',
            },
            {
              type: 'text',
              text: activityShareHighlight(activity),
              wrap: true,
              size: 'lg',
              weight: 'bold',
              color: '#98531F',
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

function activityShareStatusText(activity: VeevaActivity) {
  if (activity.status === 'archived' || !activity.active) return '已結束'
  if (activity.label.includes('即將')) return '即將開始'
  if (activity.label.includes('報名')) return '報名中'
  if (activity.type === 'registration') return '報名中'
  if (activity.type === 'survey') return '進行中'
  return activity.label || '進行中'
}

function activityShareLocation(activity: VeevaActivity) {
  if (activity.type === 'survey') return '線上問卷'
  if (activity.type === 'external' || activity.type === 'task') return '線上活動'
  return '活動地點待通知'
}

function activityShareIntro(activity: VeevaActivity) {
  const status = activityShareStatusText(activity)
  const period = activity.periodText ?? '活動時間依公告為準'
  const location = activity.location ?? activityShareLocation(activity)
  const description = truncateForLine(activity.description, 70)
  return `${status}｜${period}\n${description}\n活動地點：${location}`
}

function activityShareHighlight(activity: VeevaActivity) {
  if (activity.type === 'survey') return '完成問卷後，將由後台人工確認獎勵！'
  if (activity.type === 'registration') return '名額有限，立即報名保留席次！'
  if (activity.type === 'referral') return '邀請好友一起加入，享受會員好禮！'
  return '點擊下方按鈕，立即查看活動！'
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

function isSameOriginUrl(url?: string) {
  if (!url) return false
  try {
    return new URL(url).origin === window.location.origin
  } catch {
    return false
  }
}
