import { mkdir, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { deleteApp, initializeApp } from 'firebase/app'
import {
  collection,
  doc,
  getDocs,
  getFirestore,
  terminate,
  writeBatch,
} from 'firebase/firestore'
import {
  getDownloadURL,
  getStorage,
  ref as storageRef,
  uploadBytes,
} from 'firebase/storage'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const outputDir = path.resolve(__dirname, '..', 'tmp', 'firebase-migration')

const oldConfig = {
  apiKey: 'AIzaSyAhPSWe0Vx8DTOC7gtp5ZJO1jfBnE3Y9oU',
  authDomain: 'veeva-8d30c.firebaseapp.com',
  projectId: 'veeva-8d30c',
  storageBucket: 'veeva-8d30c.firebasestorage.app',
  messagingSenderId: '448360837259',
  appId: '1:448360837259:web:d632a699cce1259b7ee48e',
}

const newConfig = {
  apiKey: 'AIzaSyD4247GK-MCzwi63Aemf_Y9YTp9W8rILJw',
  authDomain: 'veeva-app-74c09.firebaseapp.com',
  projectId: 'veeva-app-74c09',
  storageBucket: 'veeva-app-74c09.firebasestorage.app',
  messagingSenderId: '403574131131',
  appId: '1:403574131131:web:943768242a77c2ca4adc9e',
}

const collectionsToCopy = [
  'activities',
  'adminUsers',
  'activityCompletions',
  'activityRegistrations',
  'employeeActivityLinks',
  'employeeQrVisits',
  'memberEmployeeAttributions',
  'memberNotifications',
  'memberRewardClaims',
  'memberRewards',
  'members',
  'news',
  'newsHelpfulVotes',
  'phoneVerificationRateLimits',
  'referrals',
  'reviewSubmissions',
  'rewardVouchers',
  'rewards',
  'systemSettings',
]

const imageExtensions = new Set([
  '.avif',
  '.gif',
  '.jpeg',
  '.jpg',
  '.png',
  '.svg',
  '.webp',
])

const oldApp = initializeApp(oldConfig, 'old-veeva')
const newApp = initializeApp(newConfig, 'new-veeva')
const oldDb = getFirestore(oldApp)
const newDb = getFirestore(newApp)
const oldStorage = getStorage(oldApp)
const newStorage = getStorage(newApp)

const dryRun = process.argv.includes('--dry-run')
const imageUrlCache = new Map()
const imageFailures = []
const imageCopies = []

function timestampForFileName(date = new Date()) {
  return date.toISOString().replace(/[:.]/g, '-')
}

function isPlainObject(value) {
  return Object.prototype.toString.call(value) === '[object Object]'
}

function jsonReplacer(_key, value) {
  if (value?.toDate && typeof value.toDate === 'function') {
    return {
      __type: 'Timestamp',
      seconds: value.seconds,
      nanoseconds: value.nanoseconds,
      iso: value.toDate().toISOString(),
    }
  }
  if (
    typeof value?.latitude === 'number' &&
    typeof value?.longitude === 'number' &&
    value.constructor?.name === 'GeoPoint'
  ) {
    return {
      __type: 'GeoPoint',
      latitude: value.latitude,
      longitude: value.longitude,
    }
  }
  return value
}

function looksLikeImagePath(url) {
  try {
    const parsed = new URL(url)
    const extension = path.extname(parsed.pathname).toLowerCase()
    return imageExtensions.has(extension)
  } catch {
    return false
  }
}

function isOldStorageUrl(value) {
  if (typeof value !== 'string' || !value.startsWith('http')) return false
  try {
    const parsed = new URL(value)
    return (
      parsed.hostname === 'firebasestorage.googleapis.com' &&
      (parsed.pathname.includes('/b/veeva-8d30c.firebasestorage.app/') ||
        parsed.pathname.includes('/b/veeva-8d30c.appspot.com/'))
    )
  } catch {
    return false
  }
}

function isOldGsUrl(value) {
  return (
    typeof value === 'string' &&
    (value.startsWith('gs://veeva-8d30c.firebasestorage.app/') ||
      value.startsWith('gs://veeva-8d30c.appspot.com/'))
  )
}

function isOldHostingImageUrl(value) {
  if (typeof value !== 'string') return false
  if (
    !value.startsWith('https://veeva-8d30c.web.app/') &&
    !value.startsWith('https://vevva.web.app/')
  ) {
    return false
  }
  return looksLikeImagePath(value)
}

function isMigratableUrl(value) {
  return isOldStorageUrl(value) || isOldGsUrl(value) || isOldHostingImageUrl(value)
}

function objectPathFromOldStorageUrl(value) {
  const parsed = new URL(value)
  const marker = '/o/'
  const markerIndex = parsed.pathname.indexOf(marker)
  if (markerIndex < 0) return null
  return decodeURIComponent(parsed.pathname.slice(markerIndex + marker.length))
}

function objectPathFromGsUrl(value) {
  return value
    .replace(/^gs:\/\/veeva-8d30c\.firebasestorage\.app\//, '')
    .replace(/^gs:\/\/veeva-8d30c\.appspot\.com\//, '')
}

function sanitizePathSegment(value) {
  return value.replace(/[^a-zA-Z0-9._/-]/g, '_').replace(/\/+/g, '/')
}

function targetStoragePath(sourceUrl, sourceObjectPath) {
  if (sourceObjectPath) {
    const cleanPath = sanitizePathSegment(sourceObjectPath)
    return cleanPath.startsWith('public/')
      ? cleanPath
      : `public/migrated/${cleanPath}`
  }

  const parsed = new URL(sourceUrl)
  const cleanPath = sanitizePathSegment(
    `${parsed.hostname}${parsed.pathname}`.replace(/^\/+/, ''),
  )
  return `public/migrated-hosting/${cleanPath}`
}

async function downloadImage(sourceUrl, sourceObjectPath) {
  let downloadUrl = sourceUrl
  if (sourceObjectPath && !sourceUrl.startsWith('http')) {
    downloadUrl = await getDownloadURL(storageRef(oldStorage, sourceObjectPath))
  }

  const response = await fetch(downloadUrl)
  if (!response.ok) {
    throw new Error(`download failed ${response.status} ${response.statusText}`)
  }
  const contentType =
    response.headers.get('content-type') || 'application/octet-stream'
  const bytes = new Uint8Array(await response.arrayBuffer())
  return { bytes, contentType }
}

async function migrateImageUrl(value) {
  if (imageUrlCache.has(value)) return imageUrlCache.get(value)

  let sourceObjectPath = null
  let sourceUrl = value

  if (isOldStorageUrl(value)) {
    sourceObjectPath = objectPathFromOldStorageUrl(value)
  } else if (isOldGsUrl(value)) {
    sourceObjectPath = objectPathFromGsUrl(value)
    sourceUrl = value
  } else if (!isOldHostingImageUrl(value)) {
    return value
  }

  const targetPath = targetStoragePath(value, sourceObjectPath)

  if (dryRun) {
    imageUrlCache.set(value, value)
    return value
  }

  try {
    const { bytes, contentType } = await downloadImage(sourceUrl, sourceObjectPath)
    const uploadRef = storageRef(newStorage, targetPath)
    await uploadBytes(uploadRef, bytes, { contentType })
    const newUrl = await getDownloadURL(uploadRef)
    imageUrlCache.set(value, newUrl)
    imageCopies.push({
      from: value,
      to: newUrl,
      targetPath,
      bytes: bytes.length,
      contentType,
    })
    return newUrl
  } catch (error) {
    imageFailures.push({
      url: value,
      targetPath,
      error: error instanceof Error ? error.message : String(error),
    })
    imageUrlCache.set(value, value)
    return value
  }
}

async function migrateStringValue(value) {
  if (isMigratableUrl(value)) return migrateImageUrl(value)

  let migratedValue = value
  const urlPattern =
    /(https:\/\/(?:firebasestorage\.googleapis\.com|veeva-8d30c\.web\.app|vevva\.web\.app)[^\s)"'<>]+)/g
  const matches = [...value.matchAll(urlPattern)]
    .map((match) => match[0])
    .filter(isMigratableUrl)

  if (matches.length > 0) {
    for (const url of [...new Set(matches)]) {
      const migratedUrl = await migrateImageUrl(url)
      migratedValue = migratedValue.split(url).join(migratedUrl)
    }
  }

  return migratedValue
    .split('https://veeva-8d30c.web.app')
    .join('https://veeva.web.app')
    .split('https://vevva.web.app')
    .join('https://veeva.web.app')
    .split('https://veeva-admin.web.app')
    .join('https://veeva-admin-74c09.web.app')
}

async function transformImageUrls(value) {
  if (typeof value === 'string') return migrateStringValue(value)
  if (Array.isArray(value)) {
    return Promise.all(value.map((item) => transformImageUrls(item)))
  }
  if (isPlainObject(value)) {
    if (value.toDate && typeof value.toDate === 'function') return value
    const entries = await Promise.all(
      Object.entries(value).map(async ([key, nestedValue]) => [
        key,
        await transformImageUrls(nestedValue),
      ]),
    )
    return Object.fromEntries(entries)
  }
  return value
}

async function readCollection(db, collectionName) {
  const snapshot = await getDocs(collection(db, collectionName))
  return snapshot.docs.map((snapshotDoc) => ({
    id: snapshotDoc.id,
    data: snapshotDoc.data({ serverTimestamps: 'estimate' }),
  }))
}

async function writeCollection(collectionName, docs) {
  if (dryRun || docs.length === 0) return

  let batch = writeBatch(newDb)
  let batchSize = 0

  for (const item of docs) {
    batch.set(doc(newDb, collectionName, item.id), item.data, { merge: true })
    batchSize += 1

    if (batchSize === 400) {
      await batch.commit()
      batch = writeBatch(newDb)
      batchSize = 0
    }
  }

  if (batchSize > 0) {
    await batch.commit()
  }
}

async function main() {
  await mkdir(outputDir, { recursive: true })

  const startedAt = new Date()
  const runId = timestampForFileName(startedAt)
  const beforeNew = {}
  const exportedOld = {}
  const transformed = {}
  const collectionCounts = {}

  console.log(
    `${dryRun ? '[dry-run] ' : ''}Migrating ${oldConfig.projectId} -> ${newConfig.projectId}`,
  )

  for (const collectionName of collectionsToCopy) {
    const [oldDocs, newDocs] = await Promise.all([
      readCollection(oldDb, collectionName),
      readCollection(newDb, collectionName),
    ])

    beforeNew[collectionName] = newDocs
    exportedOld[collectionName] = oldDocs

    const migratedDocs = []
    for (const item of oldDocs) {
      migratedDocs.push({
        id: item.id,
        data: await transformImageUrls(item.data),
      })
    }

    transformed[collectionName] = migratedDocs
    await writeCollection(collectionName, migratedDocs)

    collectionCounts[collectionName] = {
      old: oldDocs.length,
      newBefore: newDocs.length,
      written: dryRun ? 0 : migratedDocs.length,
    }
    console.log(
      `${collectionName}: old=${oldDocs.length}, newBefore=${newDocs.length}, written=${
        dryRun ? 0 : migratedDocs.length
      }`,
    )
  }

  const afterNew = {}
  for (const collectionName of collectionsToCopy) {
    afterNew[collectionName] = await readCollection(newDb, collectionName)
    collectionCounts[collectionName].newAfter =
      afterNew[collectionName].length
  }

  const report = {
    dryRun,
    startedAt: startedAt.toISOString(),
    finishedAt: new Date().toISOString(),
    sourceProject: oldConfig.projectId,
    targetProject: newConfig.projectId,
    collections: collectionCounts,
    images: {
      copied: imageCopies.length,
      failed: imageFailures.length,
      copies: imageCopies,
      failures: imageFailures,
    },
  }

  await Promise.all([
    writeFile(
      path.join(outputDir, `${runId}-new-before.json`),
      JSON.stringify(beforeNew, jsonReplacer, 2),
    ),
    writeFile(
      path.join(outputDir, `${runId}-old-export.json`),
      JSON.stringify(exportedOld, jsonReplacer, 2),
    ),
    writeFile(
      path.join(outputDir, `${runId}-transformed.json`),
      JSON.stringify(transformed, jsonReplacer, 2),
    ),
    writeFile(
      path.join(outputDir, `${runId}-new-after.json`),
      JSON.stringify(afterNew, jsonReplacer, 2),
    ),
    writeFile(
      path.join(outputDir, `${runId}-report.json`),
      JSON.stringify(report, null, 2),
    ),
  ])

  console.log(`Images copied=${imageCopies.length}, failed=${imageFailures.length}`)
  if (imageFailures.length > 0) {
    console.log('Image failures:')
    for (const failure of imageFailures) {
      console.log(`- ${failure.url}: ${failure.error}`)
    }
  }
  console.log(`Report: ${path.join(outputDir, `${runId}-report.json`)}`)
  await Promise.all([terminate(oldDb), terminate(newDb)])
  await Promise.all([deleteApp(oldApp), deleteApp(newApp)])
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
