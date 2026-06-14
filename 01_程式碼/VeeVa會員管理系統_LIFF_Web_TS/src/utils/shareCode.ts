export function shareCodeFromId(id: string) {
  const compact = id.replace(/[^a-zA-Z0-9]/g, '').toUpperCase()
  if (compact.length >= 5) {
    return compact.slice(compact.length - 5)
  }
  return compact.padEnd(5, 'X')
}

export function referralCodeFromLocation(location: Location = window.location) {
  const url = new URL(location.href)
  return referralCodeFromUrl(url)
}

export function referralCodeFromUrl(urlLike: string | URL) {
  const url = typeof urlLike === 'string' ? new URL(urlLike) : urlLike
  const directCode =
    url.searchParams.get('ref') ??
    url.searchParams.get('shareCode') ??
    url.searchParams.get('referralCode')
  if (directCode) {
    return cleanReferralCode(directCode)
  }

  const match = url.pathname.match(/\/r\/([^/?#]+)/)
  if (match?.[1]) {
    return cleanReferralCode(match[1])
  }

  const liffState = url.searchParams.get('liff.state')
  if (liffState) {
    try {
      const stateUrl = new URL(liffState, url.origin)
      return referralCodeFromPathAndSearch(stateUrl.pathname, stateUrl.search)
    } catch {
      const decoded = decodeURIComponent(liffState)
      const stateMatch = decoded.match(/\/r\/([^/?#]+)/)
      if (stateMatch?.[1]) {
        return cleanReferralCode(stateMatch[1])
      }
    }
  }

  return undefined
}

function referralCodeFromPathAndSearch(pathname: string, search: string) {
  const params = new URLSearchParams(search)
  const fromQuery =
    params.get('ref') ?? params.get('shareCode') ?? params.get('referralCode')
  if (fromQuery) {
    return cleanReferralCode(fromQuery)
  }
  const match = pathname.match(/\/r\/([^/?#]+)/)
  return match?.[1] ? cleanReferralCode(match[1]) : undefined
}

function cleanReferralCode(value: string) {
  const clean = value.trim().replace(/[^a-zA-Z0-9]/g, '').toUpperCase()
  return clean || undefined
}
