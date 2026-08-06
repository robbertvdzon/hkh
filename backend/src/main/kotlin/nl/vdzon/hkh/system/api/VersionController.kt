package nl.vdzon.hkh.system.api

import org.springframework.beans.factory.annotation.Value
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

data class VersionResponse(
    val application: String,
    val version: String,
    val commit: String,
)

@RestController
@RequestMapping("/api/version")
class VersionController(
    @param:Value("\${spring.application.name}") private val application: String,
    @param:Value("\${hkh.version}") private val version: String,
    @param:Value("\${hkh.commit}") private val commit: String,
) {
    @GetMapping
    fun version(): VersionResponse = VersionResponse(application, version, commit)
}
