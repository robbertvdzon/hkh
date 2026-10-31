package nl.vdzon.hkh.workflowlog

import tools.jackson.databind.JsonNode
import tools.jackson.databind.ObjectMapper
import tools.jackson.databind.node.ArrayNode
import tools.jackson.databind.node.ObjectNode

/**
 * Het meldpunt is open, dus wat binnenkomt wordt schoongemaakt voordat het wordt bewaard: waarden van velden die
 * op een geheim lijken worden vervangen (de app filtert ze ook zelf), NUL-tekens verdwijnen (Postgres weigert ze)
 * en te diepe structuren worden afgekapt. Velden met een naam in [keepNames] blijven leesbaar (zie `hkh.workflow-log.keep-ftp-password`).
 */
class WorkflowLogSanitizer(private val mapper: ObjectMapper, private val keepNames: Set<String> = emptySet()) {
    fun clean(node: JsonNode?): JsonNode = node?.takeIf { it.isObject }?.let { copy(it, 0) } ?: mapper.createObjectNode()

    fun text(value: String?, max: Int): String? = value?.replace("\u0000", "")?.trim()?.take(max)?.takeIf { it.isNotEmpty() }

    private fun copy(node: JsonNode, depth: Int): JsonNode = when {
        depth > MAX_DEPTH -> mapper.nodeFactory.stringNode("(te diep genest, weggelaten)")
        node.isObject -> {
            val out: ObjectNode = mapper.createObjectNode()
            node.properties().forEach { (name, value) ->
                val key = name.replace("\u0000", "")
                out.set(key, if (key !in keepNames && isSecretName(key) && (value.isString || value.isNumber)) mapper.nodeFactory.stringNode(REDACTED) else copy(value, depth + 1))
            }
            out
        }
        node.isArray -> {
            val out: ArrayNode = mapper.createArrayNode()
            node.forEach { out.add(copy(it, depth + 1)) }
            out
        }
        node.isString -> mapper.nodeFactory.stringNode(node.stringValue().replace("\u0000", ""))
        else -> node
    }

    companion object {
        const val REDACTED = "(weggelaten)"
        private const val MAX_DEPTH = 12
        private val SECRET_PARTS = listOf("password", "passwd", "wachtwoord", "secret", "token", "apikey", "api-key", "privatekey", "credential")

        fun isSecretName(name: String): Boolean {
            val n = name.lowercase()
            return SECRET_PARTS.any { it in n } || n.endsWith("key")
        }
    }
}
