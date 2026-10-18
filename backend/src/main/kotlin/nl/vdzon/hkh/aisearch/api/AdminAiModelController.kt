package nl.vdzon.hkh.aisearch.api

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.Instant
import nl.vdzon.hkh.aisearch.AgentRuntimeClient
import nl.vdzon.hkh.aisearch.AiExecution
import nl.vdzon.hkh.aisearch.AiModelSettings
import nl.vdzon.hkh.aisearch.AiResearchMethod
import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.research.AiRole
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.server.ResponseStatusException

data class AiExecutionView(val vendorId: String, val model: String, val mode: String, val label: String)

data class AiModelOptionView(val execution: AiExecutionView, val available: Boolean, val onlineWorkers: Int)

/** Het model van één rol, voor het overzicht in het beheerscherm. */
data class AiRoleModelView(val role: AiRole, val label: String, val current: AiExecutionView, val fromSetting: Boolean)

data class AiModelView(
    /** De rol waarvan dit de keuze is. */
    val role: AiRole,
    val current: AiExecutionView,
    /** true als een beheerder het model voor deze rol heeft gekozen; false als de rol erft of de configuratie geldt. */
    val fromSetting: Boolean,
    val updatedAt: Instant?,
    val updatedBy: String?,
    val options: List<AiModelOptionView>,
    /** Leeg als de catalogus van de runtime kon worden opgehaald; anders de reden. */
    val catalogError: String?,
    /** De onderzoeksmethode voor nieuwe vragen. */
    val method: AiResearchMethod,
    /** Alle rollen met hun huidige model. */
    val roles: List<AiRoleModelView>,
)

data class SelectAiModelRequest(
    @field:NotBlank @field:Size(max = 100) val vendorId: String,
    @field:NotBlank @field:Size(max = 160) val model: String,
    @field:NotBlank @field:Size(max = 30) val mode: String,
)

data class SelectAiMethodRequest(@field:NotBlank @field:Size(max = 20) val method: String)

/**
 * Beheer van de AI-modellen: catalogus van de runtime, de keuze per rol (agent, extractie,
 * onderzoek, schrijven) en de onderzoeksmethode.
 */
@RestController
@RequestMapping("/api/admin/ai-search")
class AdminAiModelController(
    private val settings: AiModelSettings,
    private val runtime: AgentRuntimeClient,
    private val authenticator: AdminAuthenticator,
) {
    @GetMapping("/model")
    fun get(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @RequestParam(required = false) role: String?,
    ): AiModelView {
        authenticator.authenticate(authorization, previewHeader)
        return view(parseRole(role))
    }

    @PutMapping("/model")
    fun select(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @RequestParam(required = false) role: String?,
        @Valid @RequestBody request: SelectAiModelRequest,
    ): AiModelView {
        val admin = authenticator.authenticate(authorization, previewHeader)
        val target = parseRole(role)
        val chosen = AiExecution(request.vendorId.trim(), request.model.trim(), request.mode.trim().uppercase())
        val options = runCatching { runtime.executionOptions() }.getOrElse {
            throw ResponseStatusException(HttpStatus.BAD_GATEWAY, "De catalogus van de runtime is nu niet bereikbaar; kies later opnieuw.")
        }
        if (options.none { it.execution == chosen }) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Dit model staat niet in de catalogus van de runtime.")
        }
        settings.update(target, chosen, admin.email)
        return view(target)
    }

    @DeleteMapping("/model")
    fun reset(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @RequestParam(required = false) role: String?,
    ): AiModelView {
        authenticator.authenticate(authorization, previewHeader)
        val target = parseRole(role)
        settings.reset(target)
        return view(target)
    }

    @PutMapping("/method")
    fun selectMethod(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @Valid @RequestBody request: SelectAiMethodRequest,
    ): AiModelView {
        val admin = authenticator.authenticate(authorization, previewHeader)
        val method = AiResearchMethod.entries.firstOrNull { it.name.equals(request.method.trim(), ignoreCase = true) }
            ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Onbekende onderzoeksmethode.")
        settings.updateMethod(method, admin.email)
        return view(AiRole.AGENT)
    }

    private fun parseRole(value: String?): AiRole {
        if (value.isNullOrBlank()) return AiRole.AGENT
        return AiRole.entries.firstOrNull { it.name.equals(value.trim(), ignoreCase = true) }
            ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Onbekende rol.")
    }

    private fun view(role: AiRole): AiModelView {
        val choice = settings.current(role)
        val catalog = runCatching { runtime.executionOptions() }
        val options = catalog.getOrDefault(emptyList()).map { option ->
            AiModelOptionView(option.execution.toView(), option.available, option.onlineWorkers)
        }
        return AiModelView(
            role = role,
            current = choice.execution.toView(),
            fromSetting = choice.fromSetting,
            updatedAt = choice.updatedAt,
            updatedBy = choice.updatedBy,
            options = options,
            catalogError = catalog.exceptionOrNull()?.let { "De catalogus van de runtime kon niet worden opgehaald." },
            method = settings.method(),
            roles = AiRole.entries.map { each ->
                val current = settings.current(each)
                AiRoleModelView(each, roleLabel(each), current.execution.toView(), current.fromSetting)
            },
        )
    }

    private fun roleLabel(role: AiRole) = when (role) {
        AiRole.AGENT -> "Agent (zoekt zelf via de API)"
        AiRole.EXTRACTION -> "Extractie (AI-kaarten)"
        AiRole.RESEARCH -> "Onderzoek (zoektermen en beoordelen)"
        AiRole.WRITER -> "Schrijven (het antwoord)"
    }

    private fun AiExecution.toView() = AiExecutionView(vendorId, model, mode, label)
}
