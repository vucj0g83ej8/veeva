import liff from '@line/liff'
import type { LiffProfile, LiffSession } from '../types/veeva'
import { inviteUrlForShareCode, liffId } from '../utils/inviteUrl'

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
          spacing: 'sm',
          contents: [
            {
              type: 'text',
              text: '加入會員送咖啡',
              weight: 'bold',
              size: 'xl',
              color: '#2B211A',
            },
            {
              type: 'text',
              text: `${memberName} 邀請你一起加入會員`,
              wrap: true,
              color: '#6B5A4D',
              size: 'sm',
            },
          ],
        },
        footer: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'button',
              style: 'primary',
              color: '#216B57',
              action: {
                type: 'uri',
                label: '立即加入',
                uri: inviteUrl,
              },
            },
          ],
        },
      },
    },
  ])
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
