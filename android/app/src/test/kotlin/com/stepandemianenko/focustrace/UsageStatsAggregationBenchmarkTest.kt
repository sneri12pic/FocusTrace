package com.stepandemianenko.focustrace

import org.junit.Assume.assumeTrue
import org.junit.Test
import java.time.Instant
import kotlin.math.ceil

class UsageStatsAggregationBenchmarkTest {
    @Test
    fun benchmarkFilteredAggregation() {
        assumeTrue(
            "Set FOCUSTRACE_BENCHMARK=1 to run the aggregation baseline.",
            System.getenv("FOCUSTRACE_BENCHMARK") == "1",
        )

        printMetadata()
        println("event_count,run,elapsed_ns,checksum")
        for (eventCount in EVENT_COUNTS) {
            val events = deterministicTrace(eventCount)
            val toMs = eventCount * EVENT_STEP_MS + QUERY_TAIL_MS

            repeat(WARMUP_RUNS) {
                consume(UsageStats.aggregateEvents(events, toMs, RESTRICTED_PACKAGES))
            }

            val elapsed = LongArray(MEASURED_RUNS)
            repeat(MEASURED_RUNS) { run ->
                val startedAt = System.nanoTime()
                val totals = UsageStats.aggregateEvents(events, toMs, RESTRICTED_PACKAGES)
                elapsed[run] = System.nanoTime() - startedAt
                val checksum = consume(totals)
                println("$eventCount,${run + 1},${elapsed[run]},$checksum")
            }

            val sorted = elapsed.sorted()
            println(
                "# summary,event_count=$eventCount," +
                    "p50_ns=${nearestRank(sorted, 0.50)}," +
                    "p95_ns=${nearestRank(sorted, 0.95)}," +
                    "min_ns=${sorted.first()},max_ns=${sorted.last()}",
            )
        }
    }

    private fun deterministicTrace(eventCount: Int): List<UsageStats.EventRecord> {
        return List(eventCount) { index ->
            val cycle = index / EVENTS_PER_CYCLE
            val slot = index % EVENTS_PER_CYCLE
            val timestamp = index * EVENT_STEP_MS
            val restricted = { offset: Int -> "restricted.${(cycle + offset) % RESTRICTED_COUNT}" }
            val unrestricted = { offset: Int ->
                "unrestricted.${(cycle * 2 + offset) % UNRESTRICTED_COUNT}"
            }

            when (slot) {
                0 -> foreground(restricted(0), timestamp)
                1 -> foreground(restricted(0), timestamp) // Duplicate lifecycle event.
                2 -> background(restricted(0), timestamp)
                3 -> foreground(restricted(1), timestamp)
                4 -> foreground(unrestricted(0), timestamp) // Restricted background is missing.
                5 -> background(unrestricted(0), timestamp)
                6 -> foreground(unrestricted(1), timestamp)
                7 -> background(unrestricted(1), timestamp)
                8 -> foreground(restricted(2), timestamp)
                9 -> background(restricted(2), timestamp)
                10 -> other(unrestricted(2), timestamp)
                else -> foreground(restricted(3), timestamp) // Closed by the next switch.
            }
        }
    }

    private fun consume(totals: Map<String, UsageStats.AppUsage>): Long {
        val checksum = totals.values.sumOf { it.totalMs + it.launchCount }
        sink = checksum
        return checksum
    }

    private fun nearestRank(sorted: List<Long>, percentile: Double): Long {
        val index = (ceil(percentile * sorted.size).toInt() - 1).coerceIn(sorted.indices)
        return sorted[index]
    }

    private fun printMetadata() {
        println("# benchmark=UsageStats.aggregateEvents filtered pure CPU baseline")
        println("# generated_at_utc=${Instant.now()}")
        println("# build_mode=Android debug JVM unit test")
        println("# java_version=${System.getProperty("java.version")}")
        println("# java_vm=${System.getProperty("java.vm.name")}")
        println("# kotlin_version=${KotlinVersion.CURRENT}")
        println("# os=${System.getProperty("os.name")} ${System.getProperty("os.version")}")
        println("# architecture=${System.getProperty("os.arch")}")
        println("# processor=${System.getenv("PROCESSOR_IDENTIFIER") ?: "not reported"}")
        println("# available_processors=${Runtime.getRuntime().availableProcessors()}")
        println("# max_heap_bytes=${Runtime.getRuntime().maxMemory()}")
        println("# clock=System.nanoTime")
        println("# dataset=fixed 12-event cycle; 8 restricted and 32 unrestricted packages")
        println("# warmup_runs=$WARMUP_RUNS")
        println("# measured_runs=$MEASURED_RUNS")
        println("# statistic=nearest-rank p50 and p95; dataset construction excluded")
    }

    private fun foreground(packageName: String, timestamp: Long) =
        UsageStats.EventRecord(packageName, timestamp, UsageStats.EventKind.Foreground)

    private fun background(packageName: String, timestamp: Long) =
        UsageStats.EventRecord(packageName, timestamp, UsageStats.EventKind.Background)

    private fun other(packageName: String, timestamp: Long) =
        UsageStats.EventRecord(packageName, timestamp, UsageStats.EventKind.Other)

    private companion object {
        const val WARMUP_RUNS = 10
        const val MEASURED_RUNS = 30
        const val EVENTS_PER_CYCLE = 12
        const val RESTRICTED_COUNT = 8
        const val UNRESTRICTED_COUNT = 32
        const val EVENT_STEP_MS = 250L
        const val QUERY_TAIL_MS = 1_000L
        val EVENT_COUNTS = intArrayOf(1_000, 10_000, 50_000, 100_000)
        val RESTRICTED_PACKAGES = (0 until RESTRICTED_COUNT).mapTo(mutableSetOf()) {
            "restricted.$it"
        }

        @Volatile
        var sink = 0L
    }
}
