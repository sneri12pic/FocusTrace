package com.stepandemianenko.focustrace

/**
 * Decides whether a short-form video player fills the screen, from the view ids
 * the accessibility service found visible and covering most of the screen. Only
 * the player's own containers count: a Shorts or Reels tab merely being selected
 * says nothing, and the home feeds embed small Shorts/Reels shelves.
 */
internal object ShortFormDetector {
    enum class Surface(
        val appKey: String,
        val displayName: String,
        val parentPackage: String,
        playerIds: List<String>,
    ) {
        YOUTUBE_SHORTS(
            appKey = "surface:youtube_shorts",
            displayName = "YouTube Shorts",
            parentPackage = "com.google.android.youtube",
            playerIds = listOf("reel_recycler", "reel_player_page_container", "reel_watch_player"),
        ),
        INSTAGRAM_REELS(
            appKey = "surface:instagram_reels",
            displayName = "Instagram Reels",
            parentPackage = "com.instagram.android",
            playerIds = listOf("clips_viewer_view_pager", "clips_viewer_container", "clips_video_container"),
        );

        /** Fully qualified, as findAccessibilityNodeInfosByViewId expects. */
        val viewIds: List<String> = playerIds.map { "$parentPackage:id/$it" }
    }

    fun candidateViewIds(packageName: String): List<String> =
        Surface.values().filter { it.parentPackage == packageName }.flatMap { it.viewIds }

    fun detect(packageName: String, visibleLargeViewIds: Set<String>): Surface? =
        Surface.values().firstOrNull { surface ->
            surface.parentPackage == packageName && surface.viewIds.any(visibleLargeViewIds::contains)
        }
}
