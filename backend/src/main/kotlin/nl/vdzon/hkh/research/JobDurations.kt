package nl.vdzon.hkh.research

/** Eén eerdere modelaanroep: de stap, het model, de omvang van de invoer en hoe lang hij duurde. */
data class JobDurationSample(val step: String, val model: String?, val inputChars: Int, val seconds: Long)

/**
 * Schat vooraf hoe lang een modelaanroep duurt, zodat de voortgang kan meelopen met de klok. De
 * implementatie (bij aisearch) haalt de metingen uit eerdere onderzoeken.
 */
fun interface JobDurationEstimator {
    fun estimateSeconds(role: AiRole, step: String, inputChars: Int): Int
}

/**
 * De schatting zelf, los van waar de metingen vandaan komen. Met genoeg metingen van dezelfde stap
 * en hetzelfde model die de invoergrootte kennen: een rechte lijn (vaste opstart plus tijd per
 * teken). Anders de mediaan van die stap, eerst voor het model en dan voor alle modellen. Zonder
 * metingen een vaste beginwaarde per stap.
 */
object DurationFit {
    const val MIN_SAMPLES_FOR_LINE = 8
    const val MIN_SAMPLES_FOR_MEDIAN = 3
    private val DEFAULTS = mapOf("plan" to 25, "richten" to 40, "kort" to 45, "schrijven" to 170, "uitwerken" to 300)
    private const val FALLBACK = 90

    fun estimate(samples: List<JobDurationSample>, step: String, model: String?, inputChars: Int): Int {
        val ofStep = samples.filter { it.step == step && it.seconds > 0 }
        val ofModel = ofStep.filter { model != null && it.model == model }
        val sized = ofModel.filter { it.inputChars > 0 }
        val seconds = line(sized, inputChars)
            ?: median(ofModel)
            ?: median(ofStep)
            ?: (DEFAULTS[step] ?: FALLBACK).toDouble()
        return seconds.toInt().coerceIn(5, 3_600)
    }

    /** Kleinste kwadraten op (invoertekens, seconden); null bij te weinig metingen of te weinig spreiding in grootte. */
    private fun line(samples: List<JobDurationSample>, inputChars: Int): Double? {
        if (samples.size < MIN_SAMPLES_FOR_LINE || inputChars <= 0) return null
        val meanX = samples.map { it.inputChars.toDouble() }.average()
        val meanY = samples.map { it.seconds.toDouble() }.average()
        val spread = samples.sumOf { (it.inputChars - meanX) * (it.inputChars - meanX) }
        if (spread < 1.0) return null
        // Een langere invoer duurt nooit korter; een negatieve helling is ruis.
        val slope = (samples.sumOf { (it.inputChars - meanX) * (it.seconds - meanY) } / spread).coerceAtLeast(0.0)
        val shortest = samples.minOf { it.seconds }.toDouble()
        return (meanY + slope * (inputChars - meanX)).coerceAtLeast(shortest / 2)
    }

    private fun median(samples: List<JobDurationSample>): Double? {
        if (samples.size < MIN_SAMPLES_FOR_MEDIAN) return null
        val sorted = samples.map { it.seconds }.sorted()
        return if (sorted.size % 2 == 1) sorted[sorted.size / 2].toDouble() else (sorted[sorted.size / 2 - 1] + sorted[sorted.size / 2]) / 2.0
    }

    /** Wat de gebruiker te lezen krijgt over de resterende tijd. */
    fun remainingText(remainingSeconds: Long): String = when {
        remainingSeconds < 0 -> "duurt iets langer dan verwacht"
        remainingSeconds < 15 -> "bijna klaar"
        remainingSeconds < 45 -> "nog ongeveer een halve minuut"
        remainingSeconds < 90 -> "nog ongeveer een minuut"
        else -> "nog ongeveer ${Math.round(remainingSeconds / 60.0)} minuten"
    }
}
