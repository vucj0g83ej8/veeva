import type { VeevaMember } from '../types/veeva'

const cachedMemberKey = 'veeva_cached_member_profile'
const cachedMemberTtlMs = 24 * 60 * 60 * 1000

const dateFields = [
  'phoneVerifiedAt',
  'lineIdTokenUpdatedAt',
  'createdAt',
  'lastLineLoginAt',
  'referredAt',
  'referralRewardGrantedAt',
  'employeeCreatedAt',
] as const

type MemberDateField = (typeof dateFields)[number]
type SerializableMember = Omit<VeevaMember, MemberDateField> &
  Partial<Record<MemberDateField, string>>

export function readCachedMember() {
  try {
    const raw = localStorage.getItem(cachedMemberKey)
    if (!raw) return undefined
    const parsed = JSON.parse(raw) as {
      member?: SerializableMember
      cachedAt?: string
    }
    const cachedAt = parsed.cachedAt ? new Date(parsed.cachedAt).getTime() : NaN
    if (
      !parsed.member ||
      !parsed.member.id ||
      !Number.isFinite(cachedAt) ||
      Date.now() - cachedAt > cachedMemberTtlMs
    ) {
      clearCachedMember()
      return undefined
    }

    return deserializeMember(parsed.member)
  } catch {
    clearCachedMember()
    return undefined
  }
}

export function rememberCachedMember(member: VeevaMember) {
  try {
    localStorage.setItem(
      cachedMemberKey,
      JSON.stringify({
        member: serializeMember(member),
        cachedAt: new Date().toISOString(),
      }),
    )
  } catch {
    // localStorage may be unavailable in private browser contexts.
  }
}

export function clearCachedMember() {
  try {
    localStorage.removeItem(cachedMemberKey)
  } catch {
    // Ignore storage failures.
  }
}

function serializeMember(member: VeevaMember): SerializableMember {
  const output = { ...member } as SerializableMember
  for (const field of dateFields) {
    const value = member[field]
    output[field] = value instanceof Date ? value.toISOString() : undefined
  }
  return output
}

function deserializeMember(member: SerializableMember): VeevaMember {
  const output = { ...member } as unknown as VeevaMember
  for (const field of dateFields) {
    output[field] = dateValue(member[field])
  }
  return output
}

function dateValue(value?: string) {
  if (!value) return undefined
  const date = new Date(value)
  return Number.isFinite(date.getTime()) ? date : undefined
}
