const defaultLiffId = '2010298394-7PwRtpTY'

export const liffId = import.meta.env.VITE_LIFF_ID ?? defaultLiffId

export function inviteUrlForShareCode(shareCode: string) {
  const publicLiffUrl = import.meta.env.VITE_PUBLIC_LIFF_URL
  if (publicLiffUrl) {
    return `${publicLiffUrl.replace(/\/$/, '')}/r/${shareCode}`
  }
  return `https://liff.line.me/${liffId}?ref=${encodeURIComponent(shareCode)}`
}
