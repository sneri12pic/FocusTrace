package com.stepandemianenko.focustrace

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Draws the usage bubble chart into a [Bitmap] for the home screen widgets.
 * The packing geometry and bubble styling are a Kotlin port of the Flutter
 * chart in lib/src/presentation/widgets/bubble_chart.dart, so widget and app
 * render the same layout for the same data.
 */
object BubbleChartRenderer {
    private const val BUBBLE_GAP = 4f
    private const val CANDIDATE_ANGLES = 72
    private const val GOLDEN_ANGLE = 2.399963

    fun render(
        context: Context,
        widthPx: Int,
        heightPx: Int,
        apps: List<Pair<String, Long>>,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        if (apps.isEmpty()) {
            return bitmap
        }
        val canvas = Canvas(bitmap)

        val maxMs = max(1L, apps.maxOf { it.second })
        val minDimension = min(widthPx, heightPx).toFloat()
        val minRadius = minDimension * 0.08f
        val maxRadius = minDimension * 0.28f
        val radii = apps.map { (_, totalMs) ->
            radiusForUsage(totalMs, maxMs, minRadius, maxRadius)
        }
        val centers = packBubbles(radii, widthPx.toFloat(), heightPx.toFloat())

        // Draw small bubbles first so larger icons remain visually dominant.
        val order = apps.indices.sortedBy { radii[it] }
        for (index in order) {
            drawBubble(context, canvas, centers[index], radii[index], apps[index].first)
        }
        return bitmap
    }

    internal fun radiusForUsage(
        totalMs: Long,
        maxMs: Long,
        minRadius: Float,
        maxRadius: Float,
    ): Float {
        if (maxMs <= 0L || maxRadius <= minRadius) return minRadius
        val normalized = (totalMs.toDouble() / maxMs).coerceIn(0.0, 1.0)
        val emphasized = normalized.pow(1.25)
        return minRadius + (emphasized * (maxRadius - minRadius)).toFloat()
    }

    /**
     * Greedy circle packing. Each new (smaller) bubble first tries the exact
     * tangent pockets between two placed bubbles, then single-bubble tangent
     * positions. This keeps the largest bubble central without loose stacks.
     */
    internal fun packBubbles(
        radii: List<Float>,
        width: Float,
        height: Float,
    ): List<FloatArray> {
        if (radii.isEmpty()) return emptyList()
        val centerX = width / 2
        val centerY = height / 2
        val positions = mutableListOf(floatArrayOf(centerX, centerY))

        for (index in 1 until radii.size) {
            val radius = radii[index]
            val candidates = mutableListOf<FloatArray>()

            // Exact intersections are the pockets touching two existing circles.
            for (first in positions.indices) {
                for (second in first + 1 until positions.size) {
                    candidates += tangentIntersections(
                        positions[first],
                        radii[first] + radius + BUBBLE_GAP,
                        positions[second],
                        radii[second] + radius + BUBBLE_GAP,
                    )
                }
            }

            // Sample every existing circumference for edge and one-neighbour gaps.
            val startAngle = -PI / 2 + (index - 1) * GOLDEN_ANGLE
            for (placedIndex in positions.indices) {
                val tangentDistance = radii[placedIndex] + radius + BUBBLE_GAP
                for (sample in 0 until CANDIDATE_ANGLES) {
                    val angle = startAngle + 2 * PI * sample / CANDIDATE_ANGLES
                    candidates += floatArrayOf(
                        positions[placedIndex][0] +
                            (tangentDistance * cos(angle)).toFloat(),
                        positions[placedIndex][1] +
                            (tangentDistance * sin(angle)).toFloat(),
                    )
                }
            }

            val valid = candidates.filter {
                isValidPosition(it, radius, positions, radii, width, height)
            }
            positions += bestPocket(valid, radius, positions, radii, centerX, centerY)
                ?: firstOpenRingPosition(
                    index,
                    radius,
                    positions,
                    radii,
                    centerX,
                    centerY,
                    width,
                    height,
                )
        }
        return positions
    }

    private fun bestPocket(
        candidates: List<FloatArray>,
        radius: Float,
        positions: List<FloatArray>,
        radii: List<Float>,
        centerX: Float,
        centerY: Float,
    ): FloatArray? {
        var best: FloatArray? = null
        var bestTouches = -1
        var bestDistanceSquared = Float.MAX_VALUE
        for (candidate in candidates) {
            val touches = positions.indices.count { index ->
                val distance = distance(candidate, positions[index])
                abs(distance - (radius + radii[index] + BUBBLE_GAP)) < 0.75f
            }
            val dx = candidate[0] - centerX
            val dy = candidate[1] - centerY
            val distanceSquared = dx * dx + dy * dy
            if (
                touches > bestTouches ||
                (touches == bestTouches && distanceSquared < bestDistanceSquared)
            ) {
                best = candidate
                bestTouches = touches
                bestDistanceSquared = distanceSquared
            }
        }
        return best
    }

    private fun firstOpenRingPosition(
        index: Int,
        radius: Float,
        positions: List<FloatArray>,
        radii: List<Float>,
        centerX: Float,
        centerY: Float,
        width: Float,
        height: Float,
    ): FloatArray {
        val step = max(2f, radius * 0.25f)
        var ring = step
        while (ring <= width + height) {
            for (sample in 0 until CANDIDATE_ANGLES * 2) {
                val angle = index * GOLDEN_ANGLE +
                    2 * PI * sample / (CANDIDATE_ANGLES * 2)
                val candidate = floatArrayOf(
                    centerX + (ring * cos(angle)).toFloat(),
                    centerY + (ring * sin(angle)).toFloat(),
                )
                if (isValidPosition(candidate, radius, positions, radii, width, height)) {
                    return candidate
                }
            }
            ring += step
        }

        // Only reachable when the launcher gives the widget less physical area
        // than its declared minimum size.
        return floatArrayOf(centerX, centerY).also {
            clampToBounds(it, radius, width, height)
        }
    }

    private fun isValidPosition(
        candidate: FloatArray,
        radius: Float,
        positions: List<FloatArray>,
        radii: List<Float>,
        width: Float,
        height: Float,
    ): Boolean {
        if (
            candidate[0] < radius || candidate[0] > width - radius ||
            candidate[1] < radius || candidate[1] > height - radius
        ) {
            return false
        }
        return positions.indices.none { index ->
            distance(candidate, positions[index]) <
                radius + radii[index] + BUBBLE_GAP - 0.25f
        }
    }

    private fun tangentIntersections(
        first: FloatArray,
        firstDistance: Float,
        second: FloatArray,
        secondDistance: Float,
    ): List<FloatArray> {
        val dx = (second[0] - first[0]).toDouble()
        val dy = (second[1] - first[1]).toDouble()
        val distance = sqrt(dx * dx + dy * dy)
        if (
            distance < 0.001 ||
            distance > firstDistance + secondDistance ||
            distance < abs(firstDistance - secondDistance)
        ) {
            return emptyList()
        }
        val along = (
            firstDistance * firstDistance - secondDistance * secondDistance +
                distance * distance
            ) / (2 * distance)
        val heightSquared = firstDistance * firstDistance - along * along
        if (heightSquared < -0.01) return emptyList()
        val perpendicular = sqrt(max(0.0, heightSquared))
        val middleX = first[0] + along * dx / distance
        val middleY = first[1] + along * dy / distance
        val offsetX = -dy * perpendicular / distance
        val offsetY = dx * perpendicular / distance
        return listOf(
            floatArrayOf((middleX + offsetX).toFloat(), (middleY + offsetY).toFloat()),
            floatArrayOf((middleX - offsetX).toFloat(), (middleY - offsetY).toFloat()),
        )
    }

    private fun distance(first: FloatArray, second: FloatArray): Float {
        val dx = first[0] - second[0]
        val dy = first[1] - second[1]
        return sqrt(dx * dx + dy * dy)
    }

    private fun clampToBounds(position: FloatArray, radius: Float, width: Float, height: Float) {
        position[0] = position[0].coerceIn(radius, max(radius, width - radius))
        position[1] = position[1].coerceIn(radius, max(radius, height - radius))
    }

    private fun drawBubble(
        context: Context,
        canvas: Canvas,
        center: FloatArray,
        radius: Float,
        packageName: String,
    ) {
        val cx = center[0]
        val cy = center[1]
        val label = UsageStats.appLabelFor(context, packageName)
        val colors = gradientFor(label)

        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                cx - radius, cy - radius, cx + radius, cy + radius,
                colors.first, colors.second, Shader.TileMode.CLAMP,
            )
        }
        canvas.drawCircle(cx, cy, radius, fill)

        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = max(1.5f, radius * 0.04f)
            color = Color.argb(56, 255, 255, 255)
        }
        canvas.drawCircle(cx, cy, radius, border)

        val icon = try {
            context.packageManager.getApplicationIcon(packageName)
        } catch (_: Exception) {
            null
        }
        if (icon != null) {
            val half = radius * 0.42f
            val bounds = RectF(cx - half, cy - half, cx + half, cy + half)
            val clip = Path().apply {
                addRoundRect(bounds, half * 0.56f, half * 0.56f, Path.Direction.CW)
            }
            canvas.save()
            canvas.clipPath(clip)
            icon.setBounds(
                bounds.left.toInt(), bounds.top.toInt(),
                bounds.right.toInt(), bounds.bottom.toInt(),
            )
            icon.draw(canvas)
            canvas.restore()
        } else {
            val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = radius * 0.5f
                textAlign = Paint.Align.CENTER
                isFakeBoldText = true
            }
            val initials = label.trim().take(3).uppercase()
            canvas.drawText(initials, cx, cy - (text.ascent() + text.descent()) / 2, text)
        }
    }

    /** Port of _colorsFor in usage_bubble.dart. */
    private fun gradientFor(name: String): Pair<Int, Int> {
        val normalized = name.lowercase()
        return when {
            "youtube" in normalized -> 0xFFFF5A6E to 0xFFB5122A
            "tiktok" in normalized -> 0xFF58E7FF to 0xFF171B2F
            "instagram" in normalized -> 0xFFFFC26A to 0xFFB832B2
            "code" in normalized || "editor" in normalized -> 0xFF58B7FF to 0xFF1759C8
            "chrome" in normalized || "browser" in normalized -> 0xFF5DD68D to 0xFF1B74E4
            "whatsapp" in normalized -> 0xFF52D273 to 0xFF128C7E
            "spotify" in normalized -> 0xFF69D86A to 0xFF169B45
            "discord" in normalized -> 0xFF8EA1FF to 0xFF5865F2
            "gmail" in normalized || "mail" in normalized -> 0xFFFFD166 to 0xFFE64B3C
            "settings" in normalized -> 0xFF9DA8BA to 0xFF4D5868
            else -> 0xFF7BDFF2 to 0xFF6A5AE0
        }.let { (top, bottom) -> top.toInt() to bottom.toInt() }
    }
}
