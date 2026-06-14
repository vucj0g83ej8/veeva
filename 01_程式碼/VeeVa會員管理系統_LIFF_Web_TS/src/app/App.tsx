import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { AuthNotice } from '../components/AuthNotice'
import { useVeevaApp } from '../hooks/useVeevaApp'
import { ActivityDetailPage } from '../pages/ActivityDetailPage'
import { ActivitiesPage } from '../pages/ActivitiesPage'
import { CouponsPage } from '../pages/CouponsPage'
import { NewsDetailPage } from '../pages/NewsDetailPage'
import { MemberPage } from '../pages/MemberPage'
import { NewsPage } from '../pages/NewsPage'

export function App() {
  const app = useVeevaApp()

  return (
    <AppShell app={app}>
      <AuthNotice app={app} />
      <Routes>
        <Route path="/" element={<Navigate to="/activities" replace />} />
        <Route path="/r/:shareCode" element={<Navigate to="/member" replace />} />
        <Route path="/activities" element={<ActivitiesPage app={app} />} />
        <Route
          path="/activities/:activityId"
          element={<ActivityDetailPage app={app} />}
        />
        <Route path="/news" element={<NewsPage app={app} />} />
        <Route path="/news/:newsId" element={<NewsDetailPage app={app} />} />
        <Route path="/coupons" element={<CouponsPage app={app} />} />
        <Route path="/member" element={<MemberPage app={app} />} />
        <Route path="*" element={<Navigate to="/activities" replace />} />
      </Routes>
    </AppShell>
  )
}
