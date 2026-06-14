import { useMemo, useState } from 'react'
import {
  CalendarDays,
  ChevronRight,
  HeartPulse,
  Megaphone,
  Microscope,
  Newspaper,
  Pill,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import type { VeevaNews } from '../types/veeva'

interface PageProps {
  app: VeevaAppState
}

export function NewsPage({ app }: PageProps) {
  const [selectedCategory, setSelectedCategory] = useState('all')
  const news = useMemo(
    () =>
      app.bootstrap.news
        .filter((item) => item.status === 'published')
        .sort((a, b) => b.date.localeCompare(a.date)),
    [app.bootstrap.news],
  )
  const categories = useMemo(
    () => Array.from(new Set(news.map(newsCategory))).filter(Boolean),
    [news],
  )
  const filteredNews = useMemo(
    () =>
      selectedCategory === 'all'
        ? news
        : news.filter((item) => newsCategory(item) === selectedCategory),
    [news, selectedCategory],
  )

  if (news.length === 0) {
    return (
      <section className="empty-state">
        <Newspaper size={30} />
        <h2>目前沒有最新資訊</h2>
        <p>文章發布後會顯示在這裡。</p>
      </section>
    )
  }

  return (
    <section className="news-page">
      <div className="news-filter-bar" aria-label="資訊分類">
        <div className="news-tabs" role="tablist" aria-label="最新資訊分類">
          <button
            aria-selected={selectedCategory === 'all'}
            className={`news-tab${selectedCategory === 'all' ? ' active' : ''}`}
            role="tab"
            type="button"
            onClick={() => setSelectedCategory('all')}
          >
            全部資訊
          </button>
          {categories.map((category) => (
            <button
              key={category}
              aria-selected={selectedCategory === category}
              className={`news-tab${
                selectedCategory === category ? ' active' : ''
              }`}
              role="tab"
              type="button"
              onClick={() => setSelectedCategory(category)}
            >
              {category}
            </button>
          ))}
        </div>
      </div>

      {filteredNews.length > 0 ? (
        <div className="news-list">
          {filteredNews.map((item) => (
            <NewsCard item={item} key={item.id} />
          ))}
        </div>
      ) : (
        <section className="empty-state compact">
          <Newspaper size={26} />
          <h3>目前沒有符合條件的資訊</h3>
          <p>切換分類可以查看其他文章。</p>
        </section>
      )}
    </section>
  )
}

function NewsCard({ item }: { item: VeevaNews }) {
  const category = newsCategory(item)
  const tone = newsTone(item)

  return (
    <Link
      aria-label={`查看文章：${item.title}`}
      className="news-card news-card-link"
      to={`/news/${encodeURIComponent(item.id)}`}
    >
      <div className="news-thumb-frame">
        {item.imageUrl ? (
          <img src={item.imageUrl} alt="" loading="lazy" />
        ) : (
          <div className={`news-thumb-fallback ${tone}`}>
            <NewsThumbnailIcon tone={tone} />
          </div>
        )}
        <span className={`news-category-chip ${tone}`}>{category}</span>
      </div>

      <div className="news-card-body">
        <div className="news-date-pill">
          <CalendarDays size={15} />
          <span>{formatNewsDate(item.date)}</span>
        </div>
        <h2>{item.title}</h2>
        <p>{item.summary}</p>
        <div className="news-source-row">
          <Newspaper size={16} />
          <span>{item.source}</span>
        </div>
      </div>

      <ChevronRight className="news-card-chevron" size={24} />
    </Link>
  )
}

function NewsThumbnailIcon({ tone }: { tone: string }) {
  const iconProps = { size: 48, strokeWidth: 1.8 }
  if (tone === 'product') return <Pill {...iconProps} />
  if (tone === 'research') return <Microscope {...iconProps} />
  if (tone === 'medical') return <HeartPulse {...iconProps} />
  if (tone === 'notice') return <Megaphone {...iconProps} />
  return <Newspaper {...iconProps} />
}

function newsCategory(item: VeevaNews) {
  return item.category ?? item.source ?? '最新資訊'
}

function newsTone(item: VeevaNews) {
  const text = `${item.category ?? ''} ${item.source ?? ''} ${item.title}`
  if (text.includes('產品') || text.includes('藥')) return 'product'
  if (text.includes('研究') || text.includes('成果')) return 'research'
  if (text.includes('醫療') || text.includes('臨床') || text.includes('健康')) {
    return 'medical'
  }
  if (text.includes('公告') || text.includes('提醒') || text.includes('警示')) {
    return 'notice'
  }
  return 'general'
}

function formatNewsDate(date: string) {
  return date.replaceAll('-', '/')
}
