const liffStateParam = 'liff.state'
const liffStateRouteRestoredKey = 'veeva_liff_state_route_restored'

export function wasOpenedFromLiffUrl() {
  return sessionStorage.getItem(liffStateRouteRestoredKey) === '1'
}

export function restoreLiffStateRoute(location: Location = window.location) {
  const currentUrl = new URL(location.href)
  const liffState = currentUrl.searchParams.get(liffStateParam)
  if (!liffState) return

  const stateUrl = stateUrlFromLiffState(liffState, currentUrl.origin)
  if (!stateUrl || stateUrl.origin !== currentUrl.origin) return
  if (!stateUrl.pathname.startsWith('/')) return

  const nextSearch = new URLSearchParams(currentUrl.search)
  nextSearch.delete(liffStateParam)
  stateUrl.searchParams.forEach((value, key) => {
    nextSearch.set(key, value)
  })

  const search = nextSearch.toString()
  const nextUrl = `${stateUrl.pathname}${search ? `?${search}` : ''}${stateUrl.hash || currentUrl.hash}`
  sessionStorage.setItem(liffStateRouteRestoredKey, '1')
  window.history.replaceState(window.history.state, '', nextUrl)
}

function stateUrlFromLiffState(value: string, origin: string) {
  try {
    return new URL(decodeURIComponent(value), origin)
  } catch {
    try {
      return new URL(value, origin)
    } catch {
      return undefined
    }
  }
}
