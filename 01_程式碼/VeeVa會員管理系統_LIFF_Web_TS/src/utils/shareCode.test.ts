import { describe, expect, it } from 'vitest'
import {
  referralCodeFromLocation,
  referralCodeFromUrl,
  shareCodeFromId,
} from './shareCode'

describe('shareCodeFromId', () => {
  it('uses the last five alphanumeric characters', () => {
    expect(shareCodeFromId('U920dc471eb46f54874b6c6719')).toBe('C6719')
  })

  it('pads short ids', () => {
    expect(shareCodeFromId('a8')).toBe('A8XXX')
  })
})

describe('referralCodeFromLocation', () => {
  it('reads ref query parameter', () => {
    const location = new URL('https://veeva.example/?ref=A8D2K') as unknown as Location
    expect(referralCodeFromLocation(location)).toBe('A8D2K')
  })

  it('reads short /r/:code path', () => {
    const location = new URL('https://veeva.example/r/bb123') as unknown as Location
    expect(referralCodeFromLocation(location)).toBe('BB123')
  })

  it('reads short code from a stored absolute URL', () => {
    expect(referralCodeFromUrl('https://veeva.example/r/a8d2k')).toBe('A8D2K')
  })

  it('reads ref inside liff.state', () => {
    const location = new URL(
      'https://veeva.example/?liff.state=%2Fr%2Fcc777',
    ) as unknown as Location
    expect(referralCodeFromLocation(location)).toBe('CC777')
  })
})
