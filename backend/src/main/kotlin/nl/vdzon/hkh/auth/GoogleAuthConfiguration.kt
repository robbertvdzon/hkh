package nl.vdzon.hkh.auth

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration

@Configuration
class GoogleAuthConfiguration {
    @Bean
    fun googleIdTokenVerifier(config: AdminAuthConfig): GoogleIdTokenVerifier =
        NimbusGoogleIdTokenVerifier(config.googleClientId)
}
