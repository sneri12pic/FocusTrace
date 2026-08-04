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
}
