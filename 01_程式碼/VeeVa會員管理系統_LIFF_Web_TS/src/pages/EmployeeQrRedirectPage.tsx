import { QrCode } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import type { VeevaAppState } from '../hooks/useVeevaApp'

interface PageProps {
  app: VeevaAppState
}

export function EmployeeQrRedirectPage({ app }: PageProps) {
  const { code = '' } = useParams()
  const navigate = useNavigate()
  const [message, setMessage] = useState('正在開啟活動')

  useEffect(() => {
    if (app.initializing) return
    let disposed = false

    async function trackAndOpenActivity() {
      try {
        const { recordEmployeeQrVisit } = await import('../services/veevaRepository')
        const link = await recordEmployeeQrVisit(code)
        if (disposed) return
        navigate(`/activities/${encodeURIComponent(link.activityId)}?staff=${link.code}`, {
          replace: true,
        })
      } catch (error) {
        if (disposed) return
        setMessage(error instanceof Error ? error.message : 'QR Code 無法使用')
        window.setTimeout(() => {
          if (!disposed) navigate('/activities', { replace: true })
        }, 1200)
      }
    }

    void trackAndOpenActivity()

    return () => {
      disposed = true
    }
  }, [app.initializing, code, navigate])

  return (
    <section className="empty-state employee-qr-redirect">
      <QrCode size={34} />
      <h2>{message}</h2>
      <p>請稍候，系統正在確認活動連結。</p>
    </section>
  )
}
