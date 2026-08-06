package nl.vdzon.hkh

import nl.vdzon.hkh.configuration.SecretsEnvLoader
import org.springframework.boot.SpringApplication
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.ConfigurationPropertiesScan
import org.springframework.modulith.Modulithic

@SpringBootApplication
@ConfigurationPropertiesScan
@Modulithic
class HkhApplication

fun main(args: Array<String>) {
    val application = SpringApplication(HkhApplication::class.java)
    application.setDefaultProperties(SecretsEnvLoader().resolvedValues())
    application.run(*args)
}
