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
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Draws the usage bubble chart into a [Bitmap] for the home screen widgets.
 * The packing simulation and bubble styling are a Kotlin port of the Flutter
 * chart in lib/src/presentation/widgets/bubble_chart.dart, so widget and app
 * render the same layout for the same data.
 */
object BubbleChartRenderer {
    private const val PACK_STEPS = 150
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
        val minRadius = minDimension * 0.13f
        val maxRadius = minDimension * 0.24f
        val radii = apps.map { (_, totalMs) ->
            minRadius + (totalMs.toFloat() / maxMs) * (maxRadius - minRadius)
        }
        val centers = pack(radii, widthPx.toFloat(), heightPx.toFloat())

        // Draw small bubbles first so the big ones sit on top of overlaps.
        val order = apps.indices.sortedBy { radii[it] }
        for (index in order) {
            drawBubble(context, canvas, centers[index], radii[index], apps[index].first)
        }
        return bitmap
    }

    /** Same relaxation loop as packBubbles in bubble_chart.dart, minus animation. */
    private fun pack(radii: List<Float>, width: Float, height: Float): List<FloatArray> {
        val centerX = width / 2
        val centerY = height / 2
        val farOut = width + height
        val positions = radii.indices.map { i ->
            floatArrayOf(
                (centerX + farOut * cos(i * GOLDEN_ANGLE)).toFloat(),
                (centerY + farOut * sin(i * GOLDEN_ANGLE)).toFloat(),
            ).also { clampToBounds(it, radii[i], width, height) }
        }
        val maxRadius = radii.maxOrNull() ?: return positions

        for (step in 0 until PACK_STEPS) {
            val gravity = 0.04f * (1 - step.toFloat() / PACK_STEPS)
            for (i in positions.indices) {
                val weight = (radii[i] * radii[i]) / (maxRadius * maxRadius)
                val pull = gravity * (0.2f + 0.8f * weight)
                positions[i][0] += (centerX - positions[i][0]) * pull
                positions[i][1] += (centerY - positions[i][1]) * pull
            }
            for (i in positions.indices) {
                for (j in i + 1 until positions.size) {
                    var dx = positions[j][0] - positions[i][0]
                    var dy = positions[j][1] - positions[i][1]
                    var distance = sqrt(dx * dx + dy * dy)
                    val minDistance = radii[i] + radii[j] + 4
                    if (distance >= minDistance) {
                        continue
                    }
                    if (distance < 0.01f) {
                        dx = (0.01 * cos(j * GOLDEN_ANGLE)).toFloat()
                        dy = (0.01 * sin(j * GOLDEN_ANGLE)).toFloat()
                        distance = 0.01f
                    }
                    val overlap = minDistance - distance
                    val massI = radii[i] * radii[i]
                    val massJ = radii[j] * radii[j]
                    val directionX = dx / distance
                    val directionY = dy / distance
                    positions[i][0] -= directionX * (overlap * massJ / (massI + massJ))
                    positions[i][1] -= directionY * (overlap * massJ / (massI + massJ))
                    positions[j][0] += directionX * (overlap * massI / (massI + massJ))
                    positions[j][1] += directionY * (overlap * massI / (massI + massJ))
                }
            }
            for (i in positions.indices) {
                clampToBounds(positions[i], radii[i], width, height)
            }
        }
        return positions
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
