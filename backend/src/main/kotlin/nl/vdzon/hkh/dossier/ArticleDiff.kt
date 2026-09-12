package nl.vdzon.hkh.dossier

import com.github.difflib.DiffUtils
import com.github.difflib.patch.DeltaType

enum class DiffLineType { EQUAL, INSERT, DELETE }

data class DiffLine(val type: DiffLineType, val text: String)

/** Regelgebaseerd verschil tussen twee Markdown-teksten, voor de versiegeschiedenis. */
object ArticleDiff {
    fun lines(from: String, to: String): List<DiffLine> {
        val original = from.lines()
        val revised = to.lines()
        val patch = DiffUtils.diff(original, revised)
        val result = mutableListOf<DiffLine>()
        var cursor = 0
        for (delta in patch.deltas.sortedBy { it.source.position }) {
            while (cursor < delta.source.position) result += DiffLine(DiffLineType.EQUAL, original[cursor++])
            when (delta.type) {
                DeltaType.DELETE -> delta.source.lines.forEach { result += DiffLine(DiffLineType.DELETE, it) }
                DeltaType.INSERT -> delta.target.lines.forEach { result += DiffLine(DiffLineType.INSERT, it) }
                DeltaType.CHANGE -> {
                    delta.source.lines.forEach { result += DiffLine(DiffLineType.DELETE, it) }
                    delta.target.lines.forEach { result += DiffLine(DiffLineType.INSERT, it) }
                }
                else -> {}
            }
            cursor = delta.source.position + delta.source.size()
        }
        while (cursor < original.size) result += DiffLine(DiffLineType.EQUAL, original[cursor++])
        return result
    }
}
