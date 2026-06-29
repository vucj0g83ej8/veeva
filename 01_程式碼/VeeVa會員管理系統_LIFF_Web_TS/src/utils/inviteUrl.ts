const defaultLiffId = '2010298394-7PwRtpTY'

export const liffId = import.meta.env.VITE_LIFF_ID ?? defaultLiffId

export function liffUrlForPath(path: string) {
  const normalizedPath = path.startsWith('/') ? path : `/${path}`
  return `https://liff.line.me/${liffId}${normalizedPath}`
}

export function inviteUrlForShareCode(shareCode: string) {
  const code = encodeURIComponent(shareCode)
  return liffUrlForPath(`/r/${code}?ref=${code}`)
}
