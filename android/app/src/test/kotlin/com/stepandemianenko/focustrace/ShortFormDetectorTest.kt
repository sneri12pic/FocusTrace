package com.stepandemianenko.focustrace

import com.stepandemianenko.focustrace.ShortFormDetector.Surface
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ShortFormDetectorTest {
    @Test
    fun playerIdOfTheForegroundAppDetectsItsSurface() {
        assertEquals(
            Surface.YOUTUBE_SHORTS,
            ShortFormDetector.detect(YOUTUBE, setOf(Surface.YOUTUBE_SHORTS.viewIds.first())),
        )
        assertEquals(
            Surface.INSTAGRAM_REELS,
            ShortFormDetector.detect(INSTAGRAM, setOf(Surface.INSTAGRAM_REELS.viewIds.last())),
        )
    }

    @Test
    fun noLargePlayerOrAnotherAppsIdIsNotASurface() {
        assertNull(ShortFormDetector.detect(YOUTUBE, emptySet()))
        assertNull(ShortFormDetector.detect(YOUTUBE, setOf("$YOUTUBE:id/results")))
        assertNull(ShortFormDetector.detect(INSTAGRAM, Surface.YOUTUBE_SHORTS.viewIds.toSet()))
        assertNull(ShortFormDetector.detect("com.example", Surface.YOUTUBE_SHORTS.viewIds.toSet()))
    }

    @Test
    fun candidatesAreQualifiedIdsOfThatPackageOnly() {
        assertEquals(Surface.YOUTUBE_SHORTS.viewIds, ShortFormDetector.candidateViewIds(YOUTUBE))
        assertTrue(ShortFormDetector.candidateViewIds(INSTAGRAM).all { it.startsWith("$INSTAGRAM:id/") })
        assertTrue(ShortFormDetector.candidateViewIds("com.example").isEmpty())
    }

    @Test
    fun surfaceRulesStayOutOfBlockerServicePackages() {
        val configuration = RestrictionRules.parseConfiguration(
            """{"rules":[
                {"appKey":"surface:youtube_shorts","appName":"YouTube Shorts","type":"routineBlock"},
                {"appKey":"com.example","appName":"Example","type":"routineBlock"}
            ]}""",
        )
        assertEquals(setOf("com.example"), configuration.appKeys)
        assertEquals(1, configuration.surfaceBlockReasons("surface:youtube_shorts", 0L).size)
        assertFalse(
            RestrictionRules.hasPackageRules(
                """{"rules":[{"appKey":"surface:instagram_reels","appName":"Reels","type":"routineBlock"}]}""",
            ),
        )
    }

    private companion object {
        const val YOUTUBE = "com.google.android.youtube"
        const val INSTAGRAM = "com.instagram.android"
    }
}
