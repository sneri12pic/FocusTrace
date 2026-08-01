import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/usage_session.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import 'home_shell.dart';
import 'restriction_editor_sheet.dart';

const _ctaGradient = LinearGradient(
  colors: [Color(0xFF5BC0EB), Color(0xFF3D6DF0)],
);

class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingViewModelProvider);
    // Hold the gate until installed apps arrive so the welcome orbit shows
    // real icons immediately instead of popping in.
    if (state.isLoading ||
        (!state.isCompleted && ref.watch(installedAppsProvider).isLoading)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.isCompleted) {
      return const HomeShell();
    }
    return const OnboardingScreen();
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _page = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    // Recheck permissions when the user comes back from system settings.
    // refreshSilently also reloads summaries, so the app list on the last
    // page fills in right after usage access is granted.
    ref.read(dashboardViewModelProvider.notifier).refreshSilently();
    ref.read(restrictionsViewModelProvider.notifier).refreshOverlayPermission();
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingViewModelProvider);
    final onboardingViewModel = ref.read(onboardingViewModelProvider.notifier);

    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goTo(_page - 1);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 4),
                  child: TextButton(
                    onPressed: onboardingState.isSaving
                        ? null
                        : () => onboardingViewModel.skip(),
                    child: Text(context.l10n.onboardingSkip),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: [
                    const _WelcomePage(),
                    const _AccessPage(),
                    _buildPickAppsPage(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _DotsIndicator(page: _page),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: _buildCta(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCta() {
    final onboardingState = ref.watch(onboardingViewModelProvider);
    final onboardingViewModel = ref.read(onboardingViewModelProvider.notifier);

    switch (_page) {
      case 0:
        return _GradientButton(
          label: context.l10n.onboardingGetStarted,
          onPressed: () => _goTo(1),
        );
      case 1:
        return _GradientButton(
          label: context.l10n.onboardingContinue,
          onPressed: () {
            ref
                .read(restrictionsViewModelProvider.notifier)
                .requestNotificationsPermission();
            _goTo(2);
          },
        );
      default:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GradientButton(
              label: context.l10n.onboardingStartSoftBlocks,
              onPressed:
                  onboardingState.isSaving ||
                      onboardingState.selectedAppKeys.isEmpty
                  ? null
                  : () => _completeOnboarding(_allApps()),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onboardingState.isSaving
                  ? null
                  : () => onboardingViewModel.skip(),
              child: Text(context.l10n.onboardingChooseLater),
            ),
          ],
        );
    }
  }

  Widget _buildPickAppsPage() {
    final onboardingState = ref.watch(onboardingViewModelProvider);
    final onboardingViewModel = ref.read(onboardingViewModelProvider.notifier);
    final dashboardState = ref.watch(dashboardViewModelProvider);
    final dashboardViewModel = ref.read(dashboardViewModelProvider.notifier);
    final allApps = _allApps();
    final summaries = _filteredSummaries(allApps);
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: dashboardViewModel.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        children: [
          Text(
            context.l10n.onboardingChooseWhatToLimit,
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.onboardingChooseWhatToLimitDescription,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _SearchBarBox(onChanged: (value) => setState(() => _query = value)),
          const SizedBox(height: 12),
          _DailyTargetTile(
            limitMinutes: onboardingState.limitMinutes,
            isEnabled: !onboardingState.isSaving,
            onChanged: onboardingViewModel.updateLimitMinutes,
          ),
          const SizedBox(height: 12),
          if (dashboardState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (allApps.isEmpty)
            _OnboardingInfoCard(
              title: context.l10n.onboardingNoAppsToChooseTitle,
              body: context.l10n.onboardingNoAppsToChooseBody,
            )
          else if (summaries.isEmpty)
            _OnboardingInfoCard(
              title: context.l10n.onboardingNoMatchingAppsTitle,
              body: context.l10n.onboardingNoMatchingAppsBody,
            )
          else
            for (final summary in summaries)
              _SelectableAppTile(
                summary: summary,
                isSelected: onboardingState.selectedAppKeys.contains(
                  summary.appKey,
                ),
                onChanged: onboardingState.isSaving
                    ? null
                    : (_) => onboardingViewModel.toggleApp(summary.appKey),
              ),
          if (onboardingState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.commonUnexpectedError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  /// Today's usage summaries plus every other installed app with zero usage,
  /// so search can find apps that were not used today.
  List<AppUsageSummary> _allApps() {
    final usage = ref.watch(dashboardViewModelProvider).summaries;
    final installed =
        ref.watch(installedAppsProvider).valueOrNull ??
        const <AppUsageSummary>[];
    final usedKeys = usage.map((summary) => summary.appKey).toSet();
    return [
      ...usage,
      ...installed.where((app) => !usedKeys.contains(app.appKey)),
    ];
  }

  List<AppUsageSummary> _filteredSummaries(List<AppUsageSummary> summaries) {
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? summaries.toList()
        : summaries
              .where(
                (summary) =>
                    summary.appName.toLowerCase().contains(query) ||
                    summary.appKey.toLowerCase().contains(query),
              )
              .toList();
    return visible..sort((first, second) {
      final byUsage = second.totalDurationSeconds.compareTo(
        first.totalDurationSeconds,
      );
      if (byUsage != 0) {
        return byUsage;
      }
      return first.appName.toLowerCase().compareTo(
        second.appName.toLowerCase(),
      );
    });
  }

  Future<void> _completeOnboarding(List<AppUsageSummary> summaries) async {
    await ref
        .read(onboardingViewModelProvider.notifier)
        .completeWithSoftBlocks(summaries);
    if (!ref.read(onboardingViewModelProvider).isCompleted) {
      return;
    }
    await ref.read(restrictionsViewModelProvider.notifier).load();
    if (mounted) {
      await promptRestrictionPermissionsIfNeeded(context, ref);
    }
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            context.l10n.onboardingWelcomeTitle,
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.onboardingWelcomeBody,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const Expanded(child: Center(child: _AppOrbit())),
        ],
      ),
    );
  }
}

class _AppOrbit extends ConsumerWidget {
  const _AppOrbit();

  static const _fallbackSatellites = <(IconData, Color)>[
    (Icons.music_note, Color(0xFFE91E63)),
    (Icons.chat_bubble, Color(0xFF5865F2)),
    (Icons.play_arrow, Color(0xFFE53935)),
    (Icons.photo_camera, Color(0xFF8E24AA)),
    (Icons.public, Color(0xFF1877F2)),
    (Icons.send, Color(0xFF29B6F6)),
    (Icons.videogame_asset, Color(0xFF43A047)),
    (Icons.alternate_email, Color(0xFFFF7043)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icons = (ref.watch(installedAppsProvider).valueOrNull ?? const [])
        .map((app) => app.iconBytes)
        .whereType<Uint8List>()
        .take(8)
        .toList();
    final count = icons.isEmpty ? _fallbackSatellites.length : icons.length;

    Widget satellite(int i) {
      final Widget child;
      if (icons.isEmpty) {
        final (icon, color) = _fallbackSatellites[i];
        child = Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Icon(icon, size: 22, color: Colors.white),
        );
      } else {
        child = ClipOval(
          child: Image.memory(
            icons[i],
            width: 40,
            height: 40,
            cacheWidth: 120,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      }
      return Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF5BC0EB).withValues(alpha: 0.10),
          border: Border.all(
            color: const Color(0xFF5BC0EB).withValues(alpha: 0.28),
          ),
        ),
        child: child,
      );
    }

    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _OrbitRingPainter()),
          ),
          Container(
            width: 150,
            height: 150,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: _ctaGradient,
            ),
            child: const _RoundedBars(),
          ),
          for (var i = 0; i < count; i++)
            Transform.translate(
              offset: Offset(
                120 * math.cos(-math.pi / 2 + i * 2 * math.pi / count),
                120 * math.sin(-math.pi / 2 + i * 2 * math.pi / count),
              ),
              child: satellite(i),
            ),
        ],
      ),
    );
  }
}

/// Faint concentric rings behind the orbit, same style as the dashboard's
/// bubble-chart scale rings.
class _OrbitRingPainter extends CustomPainter {
  const _OrbitRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.08);

    // 120 is the satellite orbit radius; the others echo outward/inward.
    for (final radius in const [86.0, 120.0, 148.0]) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoundedBars extends StatelessWidget {
  const _RoundedBars();

  @override
  Widget build(BuildContext context) {
    Widget bar(double height) => Container(
      width: 14,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
      ),
    );
    return Center(
      child: SizedBox(
        height: 58,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            bar(34),
            const SizedBox(width: 10),
            bar(58),
            const SizedBox(width: 10),
            bar(24),
          ],
        ),
      ),
    );
  }
}

class _AccessPage extends ConsumerWidget {
  const _AccessPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardViewModelProvider);
    final restrictionsState = ref.watch(restrictionsViewModelProvider);
    final isAndroid = dashboardState.platform == UsagePlatform.android;
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 16),
        Text(
          context.l10n.onboardingAccessTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.onboardingAccessBody,
          textAlign: TextAlign.center,
          style: mutedStyle,
        ),
        const SizedBox(height: 28),
        Center(
          child: Container(
            width: 132,
            height: 132,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: _ctaGradient,
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 64,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (!isAndroid)
          _OnboardingInfoCard(
            title: context.l10n.onboardingNoPermissionsTitle,
            body: context.l10n.onboardingNoPermissionsBody,
          )
        else ...[
          _PermissionTile(
            icon: Icons.insert_chart_outlined,
            title: context.l10n.onboardingUsageAccessTitle,
            subtitle: context.l10n.onboardingUsageAccessSubtitle,
            isGranted: dashboardState.hasUsageAccess,
            onAllow: ref
                .read(dashboardViewModelProvider.notifier)
                .openPermissionSettings,
          ),
          const SizedBox(height: 12),
          _PermissionTile(
            icon: Icons.picture_in_picture_alt_outlined,
            title: context.l10n.onboardingOverlayAccessTitle,
            subtitle: context.l10n.onboardingOverlayAccessSubtitle,
            isGranted: restrictionsState.hasOverlayPermission,
            onAllow: () => ref
                .read(restrictionsViewModelProvider.notifier)
                .openOverlaySettings(),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.onboardingPermissionsSettingsHint,
              style: mutedStyle,
            ),
          ],
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onAllow,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isGranted)
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2ECC71),
                ),
                child: const Icon(Icons.check, size: 20, color: Colors.white),
              )
            else
              _GradientButton(
                label: context.l10n.onboardingAllow,
                onPressed: onAllow,
                compact: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: onPressed == null ? null : _ctaGradient,
        color: onPressed == null
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)
            : null,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: compact ? const Size(88, 40) : const Size.fromHeight(52),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == page
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
          ),
      ],
    );
  }
}

class _SearchBarBox extends StatelessWidget {
  const _SearchBarBox({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: context.l10n.onboardingSearchApps,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.6),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.6,
            ),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _SelectableAppTile extends StatelessWidget {
  const _SelectableAppTile({
    required this.summary,
    required this.isSelected,
    required this.onChanged,
  });

  final AppUsageSummary summary;
  final bool isSelected;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: onChanged,
        secondary: _AppIcon(summary: summary),
        title: Text(
          summary.appName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          summary.totalDurationSeconds == 0
              ? summary.appKey
              : context.l10n.onboardingAppUsageToday(
                  summary.appKey,
                  context.l10n.compactDuration(summary.totalDuration),
                ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}

class _DailyTargetTile extends StatelessWidget {
  const _DailyTargetTile({
    required this.limitMinutes,
    required this.isEnabled,
    required this.onChanged,
  });

  final int limitMinutes;
  final bool isEnabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rangeStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  context.l10n.onboardingDailyTarget,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  context.l10n.compactDuration(Duration(minutes: limitMinutes)),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: limitMinutes.clamp(30, 480).toDouble(),
              min: 30,
              max: 480,
              divisions: 30,
              label: context.l10n.compactDuration(
                Duration(minutes: limitMinutes),
              ),
              onChanged: isEnabled ? (value) => onChanged(value.round()) : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.compactDuration(const Duration(minutes: 30)),
                  style: rangeStyle,
                ),
                Text(
                  context.l10n.compactDuration(const Duration(hours: 8)),
                  style: rangeStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.summary});

  final AppUsageSummary summary;

  @override
  Widget build(BuildContext context) {
    final iconBytes = summary.iconBytes;
    if (iconBytes != null) {
      return ClipOval(
        child: Image.memory(
          iconBytes,
          width: 40,
          height: 40,
          cacheWidth: 120,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return CircleAvatar(
      child: Text(
        summary.appName.isEmpty ? '?' : summary.appName[0].toUpperCase(),
      ),
    );
  }
}

class _OnboardingInfoCard extends StatelessWidget {
  const _OnboardingInfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
