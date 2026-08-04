package com.stepandemianenko.focustrace

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BubbleChartRendererTest {
    @Test
    fun fourHoursIsClearlyLargerThanTenMinutes() {
        val fourHours = BubbleChartRenderer.radiusForUsage(
            totalMs = 4 * 60 * 60 * 1_000L,
            maxMs = 4 * 60 * 60 * 1_000L,
            minRadius = 20f,
            maxRadius = 72f,
        )
        val tenMinutes = BubbleChartRenderer.radiusForUsage(
            totalMs = 10 * 60 * 1_000L,
            maxMs = 4 * 60 * 60 * 1_000L,
            minRadius = 20f,
            maxRadius = 72f,
        )

        assertEquals(72f, fourHours, 0.001f)
        assertTrue(fourHours / tenMinutes > 3.4f)
    }

    @Test
    fun smallerBubblesFillTangentPocketsWithoutOverlap() {
        val radii = listOf(72f, 60f, 48f, 36f, 30f, 26f)
        val positions = BubbleChartRenderer.packBubbles(radii, 800f, 360f)

        assertEquals(400f, positions.first()[0], 0.001f)
        assertEquals(180f, positions.first()[1], 0.001f)
        for (index in positions.indices) {
            for (other in index + 1 until positions.size) {
                val distance = distance(positions[index], positions[other])
                assertTrue(distance >= radii[index] + radii[other] + 3.5f)
            }
            if (index < 2) continue
            val tangentNeighbours = (0 until index).count { placed ->
                val tangentDistance = radii[index] + radii[placed] + 4f
                kotlin.math.abs(distance(positions[index], positions[placed]) - tangentDistance) < 1f
            }
            assertTrue(tangentNeighbours >= 2)
        }
    }

    private fun distance(first: FloatArray, second: FloatArray): Float {
        val dx = first[0] - second[0]
        val dy = first[1] - second[1]
        return kotlin.math.sqrt(dx * dx + dy * dy)
    }
}
