package nl.vdzon.hkh.news

import org.springframework.stereotype.Service

@Service
class LatestNewsService(private val store: LatestNewsStore) {
    fun findAll(): List<LatestNews> = store.findAll()

    fun create(title: String, message: String, createdBy: String): LatestNews = store.create(
        title = title.trim(),
        message = message.trim(),
        createdBy = createdBy,
    )
}
