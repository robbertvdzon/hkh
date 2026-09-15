package nl.vdzon.hkh.previewdata

import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.auth.UserAccountStore
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.ApplicationArguments
import org.springframework.boot.ApplicationRunner
import org.springframework.stereotype.Component

/** Testidentiteiten worden uitsluitend in de bestaande afgeschermde previewdatabase aangemaakt. */
@Component
class AgentTestAccount(private val preview: PreviewRuntimeConfig, private val users: UserAccountStore,
    @Value("\${AI_ACCESS_EMAILS:}") private val emails: String) : ApplicationRunner {
    override fun run(args: ApplicationArguments) {
        if (!preview.enabled) return
        emails.split(',').map(String::trim).filter(String::isNotBlank).forEach {
            require(it.endsWith("@hkh.invalid")) { "Testaccount moet een synthetische identiteit zijn" }
            users.findOrCreateUser(it, "Testgebruiker")
        }
    }
}
