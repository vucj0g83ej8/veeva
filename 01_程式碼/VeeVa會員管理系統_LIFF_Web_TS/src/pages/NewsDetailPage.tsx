import {
  ArrowLeft,
  Bookmark,
  CalendarDays,
  FileText,
  Newspaper,
  Share2,
  Tag,
  UserRound,
} from 'lucide-react'
import type { ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'
import type { VeevaAppState } from '../hooks/useVeevaApp'
import type { VeevaNews } from '../types/veeva'

interface PageProps {
  app: VeevaAppState
}

export function NewsDetailPage({ app }: PageProps) {
  const { newsId = '' } = useParams()
  const decodedNewsId = safeDecode(newsId)
  const article = app.bootstrap.news.find((item) => item.id === decodedNewsId)

  if (!article) {
    return (
      <section className="empty-state">
        <Newspaper size={30} />
        <h2>找不到文章</h2>
        <p>這篇文章可能已下架或尚未發布。</p>
        <Link className="secondary-button" to="/news">
          <ArrowLeft size={18} />
          回最新資訊
        </Link>
      </section>
    )
  }

  const category = article.category ?? article.source ?? '最新資訊'
  const articleContent = article.detailContent ?? article.content ?? article.summary
  const helpfulCount = article.helpfulCount ?? 12

  return (
    <article className="article-detail">
      <div className="article-detail-toolbar" aria-label="文章操作">
        <Link className="article-icon-link" to="/news" aria-label="回最新資訊">
          <ArrowLeft size={23} />
        </Link>
        <div className="article-toolbar-actions">
          <button className="article-icon-button" type="button" aria-label="收藏文章">
            <Bookmark size={22} />
          </button>
          <button
            className="article-icon-button"
            type="button"
            aria-label="分享文章"
            onClick={() => shareArticle(article)}
          >
            <Share2 size={22} />
          </button>
        </div>
      </div>

      <header className="article-hero">
        <div className="article-meta-row">
          <span className={`article-category-pill ${newsTone(article)}`}>
            {category}
          </span>
          <span className="article-date-pill">
            <CalendarDays size={15} />
            {formatNewsDate(article.date)}
          </span>
        </div>

        <h2>{article.title}</h2>

        <div className="article-source-line">
          <FileText size={18} />
          <span>{article.source || 'VeeVa Member'}</span>
        </div>
      </header>

      <section className="article-freeform-content">
        {renderArticleBlocks(articleContent)}
      </section>

      <section className="article-info-card">
        <h3>關鍵資訊</h3>
        <ArticleInfoRow
          icon={CalendarDays}
          label="發布日期"
          value={formatNewsDate(article.date)}
        />
        <ArticleInfoRow
          icon={UserRound}
          label="發布單位"
          value={article.source || 'VeeVa Member'}
        />
        <ArticleInfoRow icon={Tag} label="分類" value={category} />
        {article.externalUrl && (
          <a
            className="article-source-link"
            href={article.externalUrl}
            target="_blank"
            rel="noreferrer"
          >
            <FileText size={18} />
            查看原文
          </a>
        )}
      </section>

      <div className="article-helpful-bar">
        <span className="article-helpful-icon">
          <Bookmark size={18} />
        </span>
        <strong>{helpfulCount} 人覺得這則資訊有幫助</strong>
      </div>
    </article>
  )
}

function ArticleInfoRow({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof CalendarDays
  label: string
  value: string
}) {
  return (
    <div className="article-info-row">
      <Icon size={19} />
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  )
}

function renderArticleBlocks(content: string) {
  const blocks: ReactNode[] = []
  let paragraphLines: string[] = []
  let listType: 'ul' | 'ol' | null = null
  let listItems: string[] = []

  const flushParagraph = () => {
    if (paragraphLines.length === 0) return
    const text = paragraphLines.join('\n').trim()
    if (text) {
      blocks.push(
        <p className="article-body" key={`p-${blocks.length}`}>
          {renderInline(text)}
        </p>,
      )
    }
    paragraphLines = []
  }

  const flushList = () => {
    if (!listType || listItems.length === 0) return
    const ListTag = listType
    blocks.push(
      <ListTag className="article-freeform-list" key={`list-${blocks.length}`}>
        {listItems.map((item) => (
          <li key={item}>{renderInline(item)}</li>
        ))}
      </ListTag>,
    )
    listType = null
    listItems = []
  }

  content.split(/\r?\n/).forEach((line) => {
    const trimmed = line.trim()
    if (!trimmed) {
      flushParagraph()
      flushList()
      return
    }

    const imageMatch = trimmed.match(/^!\[([^\]]*)\]\((https?:\/\/[^)]+)\)$/)
    const headingMatch = trimmed.match(/^(#{1,3})\s+(.+)$/)
    const bulletMatch = trimmed.match(/^[-*•]\s+(.+)$/)
    const numberMatch = trimmed.match(/^\d+\.\s+(.+)$/)
    const quoteMatch = trimmed.match(/^>\s+(.+)$/)

    if (/^-{3,}$/.test(trimmed)) {
      flushParagraph()
      flushList()
      blocks.push(<hr className="article-freeform-rule" key={`hr-${blocks.length}`} />)
      return
    }

    if (imageMatch) {
      flushParagraph()
      flushList()
      blocks.push(
        <img
          alt={imageMatch[1]}
          className="article-freeform-image"
          key={`img-${blocks.length}`}
          src={imageMatch[2]}
        />,
      )
      return
    }

    if (headingMatch) {
      flushParagraph()
      flushList()
      const HeadingTag = headingMatch[1].length === 1 ? 'h2' : 'h3'
      blocks.push(
        <HeadingTag
          className="article-freeform-heading"
          key={`h-${blocks.length}`}
        >
          {renderInline(headingMatch[2])}
        </HeadingTag>,
      )
      return
    }

    if (bulletMatch || numberMatch) {
      flushParagraph()
      const nextType = bulletMatch ? 'ul' : 'ol'
      if (listType && listType !== nextType) flushList()
      listType = nextType
      listItems.push((bulletMatch?.[1] ?? numberMatch?.[1] ?? '').trim())
      return
    }

    if (quoteMatch) {
      flushParagraph()
      flushList()
      blocks.push(
        <blockquote className="article-freeform-quote" key={`q-${blocks.length}`}>
          {renderInline(quoteMatch[1])}
        </blockquote>,
      )
      return
    }

    flushList()
    paragraphLines.push(line)
  })

  flushParagraph()
  flushList()

  return blocks.length > 0 ? blocks : null
}

function renderInline(text: string) {
  const tokens = text.split(
    /(\{\{fs:\d{1,2}\}\}[\s\S]+?\{\{\/fs\}\}|\*\*[^\n]+?\*\*|_[^_]+_|\[[^\]]+\]\(https?:\/\/[^)]+\))/g,
  )

  return tokens.map((token, index) => {
    if (!token) return null
    const fontSize = token.match(/^\{\{fs:(\d{1,2})\}\}([\s\S]+)\{\{\/fs\}\}$/)
    if (fontSize) {
      const size = normalizeArticleFontSize(Number(fontSize[1]))
      return (
        <span
          className="article-inline-size"
          key={`${token}-${index}`}
          style={{ fontSize: `${size}px` }}
        >
          {renderInline(fontSize[2])}
        </span>
      )
    }
    const link = token.match(/^\[([^\]]+)\]\((https?:\/\/[^)]+)\)$/)
    if (link) {
      return (
        <a
          className="article-inline-link"
          href={link[2]}
          key={`${token}-${index}`}
          target="_blank"
          rel="noreferrer"
        >
          {link[1]}
        </a>
      )
    }
    if (token.startsWith('**') && token.endsWith('**')) {
      return <strong key={`${token}-${index}`}>{token.slice(2, -2)}</strong>
    }
    if (token.startsWith('_') && token.endsWith('_')) {
      return <em key={`${token}-${index}`}>{token.slice(1, -1)}</em>
    }
    return token
  })
}

function normalizeArticleFontSize(size: number) {
  if (!Number.isFinite(size)) return 16
  return Math.min(36, Math.max(12, size))
}

function safeDecode(value: string) {
  try {
    return decodeURIComponent(value)
  } catch {
    return value
  }
}

function shareArticle(article: VeevaNews) {
  const url = window.location.href
  if (navigator.share) {
    void navigator.share({
      title: article.title,
      text: article.summary,
      url,
    })
    return
  }
  void navigator.clipboard?.writeText(url)
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
