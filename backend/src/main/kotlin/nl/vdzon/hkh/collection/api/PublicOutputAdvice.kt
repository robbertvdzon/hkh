package nl.vdzon.hkh.collection.api

import nl.vdzon.hkh.collection.CollectionLinks
import org.springframework.core.MethodParameter
import org.springframework.http.MediaType
import org.springframework.http.converter.HttpMessageConverter
import org.springframework.http.server.ServerHttpRequest
import org.springframework.http.server.ServerHttpResponse
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.servlet.mvc.method.annotation.ResponseBodyAdvice
import tools.jackson.databind.ObjectMapper

/** Apply at read time too: answers and article versions already stored must remain usable. */
@RestControllerAdvice(basePackages = ["nl.vdzon.hkh"])
class PublicOutputAdvice(private val mapper: ObjectMapper) : ResponseBodyAdvice<Any> {
    override fun supports(returnType: MethodParameter, converterType: Class<out HttpMessageConverter<*>>) = true

    override fun beforeBodyWrite(body: Any?, returnType: MethodParameter, selectedContentType: MediaType,
        selectedConverterType: Class<out HttpMessageConverter<*>>, request: ServerHttpRequest,
        response: ServerHttpResponse): Any? {
        if (body == null || !MediaType.APPLICATION_JSON.isCompatibleWith(selectedContentType)) return body
        return mapper.valueToTree(rewrite(mapper.convertValue(body, Any::class.java)))
    }

    private fun rewrite(value: Any?): Any? = when (value) {
        is String -> CollectionLinks.rewrite(value)
        is Map<*, *> -> value.entries.associate { (key, entry) -> (if (key is String) CollectionLinks.rewrite(key) else key) to rewrite(entry) }
        is List<*> -> value.map(::rewrite)
        else -> value
    }
}
