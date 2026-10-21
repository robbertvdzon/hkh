package nl.vdzon.hkh.news.api

import java.time.Instant
import nl.vdzon.hkh.news.LatestNews
import nl.vdzon.hkh.news.LatestNewsService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

data class LatestNewsResponse(
    val id: Long,
    val title: String,
    val message: String,
    val publishedAt: Instant,
    val createdAt: Instant,
)

@RestController
@RequestMapping("/api/news")
class LatestNewsController(private val service: LatestNewsService) {
    @GetMapping
    fun findAll(): List<LatestNewsResponse> = service.findAll().map(LatestNews::toResponse)
}

private fun LatestNews.toResponse() = LatestNewsResponse(id, title, message, publishedAt, createdAt)
