import { Navigate, Route, Routes, useParams } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { AuthNotice } from '../components/AuthNotice'
import { useVeevaApp } from '../hooks/useVeevaApp'
import { ActivityDetailPage } from '../pages/ActivityDetailPage'
import { ActivitiesPage } from '../pages/ActivitiesPage'
import { CouponsPage } from '../pages/CouponsPage'
import { EmployeeQrRedirectPage } from '../pages/EmployeeQrRedirectPage'
import { NewsDetailPage } from '../pages/NewsDetailPage'
import { MemberPage } from '../pages/MemberPage'
import { NewsPage } from '../pages/NewsPage'
import { SurveyPage } from '../pages/SurveyPage'

export function App() {
  const app = useVeevaApp()
  const newsEnabled = app.bootstrap.clientSettings.newsEnabled

  return (
    <AppShell app={app}>
      <AuthNotice app={app} />
      <Routes>
        <Route path="/" element={<Navigate to="/activities" replace />} />
        <Route path="/r/:shareCode" element={<ReferralRedirect />} />
        <Route path="/e/:code" element={<EmployeeQrRedirectPage app={app} />} />
        <Route path="/activities" element={<ActivitiesPage app={app} />} />
        <Route
          path="/activities/:activityId/survey"
          element={<SurveyPage app={app} />}
        />
        <Route
          path="/activities/:activityId"
          element={<ActivityDetailPage app={app} />}
        />
        <Route
          path="/news"
          element={
            newsEnabled ? <NewsPage app={app} /> : <Navigate to="/activities" replace />
          }
        />
        <Route
          path="/news/:newsId"
          element={
            newsEnabled ? (
              <NewsDetailPage app={app} />
            ) : (
              <Navigate to="/activities" replace />
            )
          }
        />
        <Route path="/coupons" element={<CouponsPage app={app} />} />
        <Route path="/member" element={<MemberPage app={app} />} />
        <Route path="*" element={<Navigate to="/activities" replace />} />
      </Routes>
    </AppShell>
  )
}

function ReferralRedirect() {
  const { shareCode } = useParams()
  const code = shareCode ? encodeURIComponent(shareCode) : ''
  return <Navigate to={`/member${code ? `?ref=${code}` : ''}`} replace />
}
