import { useMemo, useState } from 'react'
import {
  CalendarDays,
  ChevronRight,
  MapPin,
  Megaphone,
  Microscope,
  NotebookPen,
  Stethoscope,
  UsersRound,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import type { VeevaActivity, VeevaActivityRegistration } from '../types/veeva'

interface PageProps {
  app: VeevaAppState
}

type ActivityFilter = 'all' | 'upcoming' | 'registered' | 'completed'
type ActivityPhase = 'upcoming' | 'open' | 'ended'

const activityFilters: Array<{ key: ActivityFilter; label: string }> = [
  { key: 'all', label: '全部活動' },
  { key: 'upcoming', label: '即將開始' },
  { key: 'registered', label: '已報名' },
  { key: 'completed', label: '已完成' },
]

export function ActivitiesPage({ app }: PageProps) {
  const [selectedFilter, setSelectedFilter] = useState<ActivityFilter>('all')
  const activityRecordById = useMemo(
    () => activityRecordsByActivityId(app.memberActivityRecords),
    [app.memberActivityRecords],
  )
  const activities = useMemo(
    () =>
      app.bootstrap.activities
        .filter(
          (activity) =>
            activity.status === 'published' || activity.status === 'archived',
        )
        .filter((activity) =>
          shouldShowActivity(activity, activityRecordById.get(activity.id)),
        )
        .sort((a, b) =>
          sortActivities(
            a,
            b,
            activityRecordById.get(a.id),
            activityRecordById.get(b.id),
          ),
        ),
    [activityRecordById, app.bootstrap.activities],
  )

  const filteredActivities = useMemo(
    () =>
      activities.filter((activity) => {
        if (selectedFilter === 'all') return true
        const record = activityRecordById.get(activity.id)
        if (selectedFilter === 'registered') {
          return record?.status === 'registered'
        }
        if (selectedFilter === 'completed') {
          return record?.status === 'completed'
        }
        return activityPhase(activity) === 'upcoming'
      }),
    [activities, activityRecordById, selectedFilter],
  )

  if (activities.length === 0) {
    return (
      <section className="empty-state">
        <Megaphone size={30} />
        <h2>目前沒有進行中的活動</h2>
        <p>新的活動上架後會顯示在這裡。</p>
      </section>
    )
  }

  return (
    <section className="activities-page">
      <div className="activities-filter-bar" aria-label="活動分類">
        <div className="activity-tabs" role="tablist" aria-label="活動狀態">
          {activityFilters.map((filter) => (
            <button
              key={filter.key}
              aria-selected={selectedFilter === filter.key}
              className={`activity-tab${
                selectedFilter === filter.key ? ' active' : ''
              }`}
              role="tab"
              type="button"
              onClick={() => setSelectedFilter(filter.key)}
            >
              {filter.label}
            </button>
          ))}
        </div>
      </div>

      {filteredActivities.length > 0 ? (
        <div className="activity-list">
          {filteredActivities.map((activity) => (
            <ActivityCard
              key={activity.id}
              activity={activity}
              record={activityRecordById.get(activity.id)}
            />
          ))}
        </div>
      ) : (
        <section className="empty-state compact">
          <Megaphone size={26} />
          <h3>目前沒有符合條件的活動</h3>
          <p>切換分類可以查看其他活動。</p>
        </section>
      )}
    </section>
  )
}

function ActivityCard({
  activity,
  record,
}: {
  activity: VeevaActivity
  record?: VeevaActivityRegistration
}) {
  const statusLabel = activityStatusLabel(activity, record)
  const location = activity.location ?? fallbackLocation(activity)
  const statusClassName = activityStatusClassName(activity, record)

  return (
    <Link
      aria-label={`查看活動：${activity.title}`}
      className="activity-card activity-card-link"
      to={`/activities/${encodeURIComponent(activity.id)}`}
    >
      <div className="activity-thumb-frame">
        {activity.imageUrl ? (
          <img src={activity.imageUrl} alt="" loading="lazy" />
        ) : (
          <div className={`activity-thumb-fallback ${activity.type}`}>
            <ActivityThumbnailIcon type={activity.type} />
          </div>
        )}
        <span className={`activity-status-chip ${statusClassName}`}>
          {statusLabel}
        </span>
      </div>

      <div className="activity-card-body">
        <div className="activity-date-pill">
          <CalendarDays size={15} />
          <span>{activity.periodText ?? '期間未設定'}</span>
        </div>
        <h2>{activity.title}</h2>
        <p>{activity.description}</p>
        <div className="activity-location-row">
          <MapPin size={16} />
          <span>{location}</span>
        </div>
      </div>

      <ChevronRight className="activity-card-chevron" size={24} />
    </Link>
  )
}

function ActivityThumbnailIcon({ type }: { type: VeevaActivity['type'] }) {
  const iconProps = { size: 48, strokeWidth: 1.8 }
  if (type === 'survey') return <NotebookPen {...iconProps} />
  if (type === 'registration') return <UsersRound {...iconProps} />
  if (type === 'checkin') return <Stethoscope {...iconProps} />
  if (type === 'task') return <Microscope {...iconProps} />
  return <Megaphone {...iconProps} />
}

function activityStatusLabel(
  activity: VeevaActivity,
  record?: VeevaActivityRegistration,
) {
  if (record?.status === 'completed') return '已完成'
  if (record?.status === 'registered') return '已報名'
  const phase = activityPhase(activity)
  if (phase === 'ended') return '已結束'
  if (phase === 'upcoming') return '即將開始'
  if (activity.label.includes('報名')) return '報名中'
  if (activity.type === 'registration') return '報名中'
  if (activity.type === 'survey') return '進行中'
  return activity.label || '進行中'
}

function activityStatusClassName(
  activity: VeevaActivity,
  record?: VeevaActivityRegistration,
) {
  if (record?.status) return record.status
  return activityPhase(activity)
}

function fallbackLocation(activity: VeevaActivity) {
  if (activity.type === 'survey') return '線上問卷'
  if (activity.type === 'registration') return '活動地點待通知'
  if (activity.type === 'external') return '線上活動'
  return '地點待通知'
}

function activityRecordsByActivityId(records: VeevaActivityRegistration[]) {
  return records.reduce<Map<string, VeevaActivityRegistration>>(
    (recordMap, record) => {
      const existing = recordMap.get(record.activityId)
      if (!existing || record.status === 'completed') {
        recordMap.set(record.activityId, record)
      }
      return recordMap
    },
    new Map(),
  )
}

function shouldShowActivity(
  activity: VeevaActivity,
  record?: VeevaActivityRegistration,
) {
  if (record) return true
  return activityPhase(activity) !== 'ended'
}

function activityPhase(activity: VeevaActivity): ActivityPhase {
  if (activity.status === 'archived' || !activity.active) return 'ended'
  const range = activityDateRange(activity.periodText)
  const todayStart = startOfToday()
  const todayEnd = endOfToday()
  if (range.end && range.end < todayStart) return 'ended'
  if (range.start && range.start > todayEnd) return 'upcoming'
  if (activity.label.includes('即將')) return 'upcoming'
  return 'open'
}

function sortActivities(
  a: VeevaActivity,
  b: VeevaActivity,
  aRecord?: VeevaActivityRegistration,
  bRecord?: VeevaActivityRegistration,
) {
  const statusDiff = statusWeight(a, aRecord) - statusWeight(b, bRecord)
  if (statusDiff !== 0) return statusDiff
  return a.title.localeCompare(b.title, 'zh-Hant')
}

function statusWeight(
  activity: VeevaActivity,
  record?: VeevaActivityRegistration,
) {
  if (record?.status === 'registered') return 0
  if (activityPhase(activity) === 'open') return 1
  if (activityPhase(activity) === 'upcoming') return 2
  if (record?.status === 'completed') return 3
  return 4
}

function activityDateRange(periodText?: string) {
  if (!periodText) return {}
  const matches = Array.from(
    periodText.matchAll(/(\d{4})[/-](\d{1,2})[/-](\d{1,2})/g),
  )
  const dates = matches.map((match) =>
    new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3])),
  )
  const start = dates[0]
  const end = dates[1] ? endOfDay(dates[1]) : undefined
  return { start, end }
}

function startOfToday() {
  const now = new Date()
  return new Date(now.getFullYear(), now.getMonth(), now.getDate())
}

function endOfToday() {
  return endOfDay(startOfToday())
}

function endOfDay(date: Date) {
  return new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate(),
    23,
    59,
    59,
    999,
  )
}
