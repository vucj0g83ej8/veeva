const officialAccountFriendshipCacheKey =
  'veeva_official_account_friendship_cache'
const officialAccountFriendshipCacheTtlMs = 6 * 60 * 60 * 1000

export interface CachedOfficialAccountFriendshipResult {
  friend: boolean
  supported: boolean
}

interface CachedOfficialAccountFriendship {
  friend: boolean
  supported: boolean
  lineUserId?: string
  checkedAt: string
}

export function getCachedOfficialAccountFriendship(lineUserId?: string) {
  try {
    const raw = localStorage.getItem(officialAccountFriendshipCacheKey)
    if (!raw) return undefined
    const cached = JSON.parse(raw) as CachedOfficialAccountFriendship
    const checkedAt = new Date(cached.checkedAt).getTime()
    const expired =
      !Number.isFinite(checkedAt) ||
      Date.now() - checkedAt > officialAccountFriendshipCacheTtlMs
    const mismatchedUser =
      Boolean(lineUserId) &&
      Boolean(cached.lineUserId) &&
      cached.lineUserId !== lineUserId

    if (expired || mismatchedUser) {
      clearCachedOfficialAccountFriendship()
      return undefined
    }

    return {
      friend: cached.friend,
      supported: cached.supported,
    } satisfies CachedOfficialAccountFriendshipResult
  } catch {
    clearCachedOfficialAccountFriendship()
    return undefined
  }
}

export function rememberOfficialAccountFriendship(
  result: CachedOfficialAccountFriendshipResult,
  lineUserId?: string,
) {
  try {
    if (!result.friend) {
      clearCachedOfficialAccountFriendship()
      return
    }
    localStorage.setItem(
      officialAccountFriendshipCacheKey,
      JSON.stringify({
        friend: true,
        supported: result.supported,
        lineUserId,
        checkedAt: new Date().toISOString(),
      } satisfies CachedOfficialAccountFriendship),
    )
  } catch {
    // A cache miss is fine; the next app open can still call the LIFF API.
  }
}

export function clearCachedOfficialAccountFriendship() {
  try {
    localStorage.removeItem(officialAccountFriendshipCacheKey)
  } catch {
    // Ignore storage failures.
  }
}
