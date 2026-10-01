package nl.vdzon.hkh.aisearch.api

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.Instant
import nl.vdzon.hkh.aisearch.AgentRuntimeClient
import nl.vdzon.hkh.aisearch.AiExecution
import nl.vdzon.hkh.aisearch.AiModelSettings
import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.server.ResponseStatusException

data class AiExecutionView(val vendorId: String, val model: String, val mode: String, val label: String)

data class AiModelOptionView(val execution: AiExecutionView, val available: Boolean, val onlineWorkers: Int)

data class AiModelView(
    val current: AiExecutionView,
    /** true als een beheerder het model heeft gekozen; false als de configuratie geldt. */
    val fromSetting: Boolean,
    val updatedAt: Instant?,
    val updatedBy: String?,
    val options: List<AiModelOptionView>,
    /** Leeg als de catalogus van de runtime kon worden opgehaald; anders de reden. */
    val catalogError: String?,
)

data class SelectAiModelRequest(
    @field:NotBlank @field:Size(max = 100) val vendorId: String,
    @field:NotBlank @field:Size(max = 160) val model: String,
    @field:NotBlank @field:Size(max = 30) val mode: String,
)

/** Beheer van het AI-model van de digitale onderzoeker: catalogus van de runtime en de actieve keuze. */
@RestController
@RequestMapping("/api/admin/ai-search/model")
class AdminAiModelController(
    private val settings: AiModelSettings,
    private val runtime: AgentRuntimeClient,
    private val authenticator: AdminAuthenticator,
) {
    @GetMapping
    fun get(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): AiModelView {
        authenticator.authenticate(authorization, previewHeader)
        return view()
    }

    @PutMapping
    fun select(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @Valid @RequestBody request: SelectAiModelRequest,
    ): AiModelView {
        val admin = authenticator.authenticate(authorization, previewHeader)
        val chosen = AiExecution(request.vendorId.trim(), request.model.trim(), request.mode.trim().uppercase())
        val options = runCatching { runtime.executionOptions() }.getOrElse {
            throw ResponseStatusException(HttpStatus.BAD_GATEWAY, "De catalogus van de runtime is nu niet bereikbaar; kies later opnieuw.")
        }
        if (options.none { it.execution == chosen }) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Dit model staat niet in de catalogus van de runtime.")
        }
        settings.update(chosen, admin.email)
        return view()
    }

    @DeleteMapping
    fun reset(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): AiModelView {
        authenticator.authenticate(authorization, previewHeader)
        settings.reset()
        return view()
    }

    private fun view(): AiModelView {
        val choice = settings.current()
        val catalog = runCatching { runtime.executionOptions() }
        val options = catalog.getOrDefault(emptyList()).map { option ->
            AiModelOptionView(option.execution.toView(), option.available, option.onlineWorkers)
        }
        return AiModelView(
            current = choice.execution.toView(),
            fromSetting = choice.fromSetting,
            updatedAt = choice.updatedAt,
            updatedBy = choice.updatedBy,
            options = options,
            catalogError = catalog.exceptionOrNull()?.let { "De catalogus van de runtime kon niet worden opgehaald." },
        )
    }

    private fun AiExecution.toView() = AiExecutionView(vendorId, model, mode, label)
}
