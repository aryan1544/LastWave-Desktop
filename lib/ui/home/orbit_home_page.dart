import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/track_actions.dart' show playGenerated;
import '../../core/audio/stream_models.dart' show PlayableTrack, RepeatMode;
import '../../features/feed/feed_repository.dart';
import '../../features/home/home_providers.dart';
import '../../features/lastfm/auth_repository.dart';
import '../../features/player/playback_service.dart';
import '../../features/player/player_state.dart' show PlayerSnapshot;
import '../theme/tokens.dart' show waveIsDark;

/// Orbit is an alternative home experience for LastWave Desktop.
/// It reuses LastWave's existing feed and playback services; the redesign is
/// intentionally isolated from playback/network/auth implementation.
class OrbitHomePage extends ConsumerWidget {
  const OrbitHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final auth = ref.watch(authRepositoryProvider);
    final playback = ref.watch(playbackServiceProvider);
    final palette = _OrbitPalette(waveIsDark(context));
    final user = auth.status == AuthStatus.signedIn && auth.username.isNotEmpty
        ? auth.username
        : 'listener';
    final hour = DateTime.now().hour;
    final greeting = hour < 5
        ? 'Still up'
        : hour < 12
            ? 'Good morning'
            : hour < 18
                ? 'Good afternoon'
                : 'Good evening';

    void playAt(List<GeneratedTrack> tracks, int index, {String source = 'Orbit'}) {
      if (tracks.isEmpty || index < 0 || index >= tracks.length) return;
      unawaited(playGenerated(
        ref,
        context,
        tracks[index],
        sourceLabel: source,
        queueAll: tracks,
        startIndex: index,
      ));
    }

    return Container(
      color: palette.canvas,
      child: feedAsync.when(
        loading: () => _OrbitLoading(palette: palette),
        error: (_, __) => _OrbitError(
          palette: palette,
          onRetry: () => ref.invalidate(feedProvider),
        ),
        data: (feed) {
          final heroTracks = feed.quickPicks.isNotEmpty
              ? feed.quickPicks
              : feed.heavyRotation.isNotEmpty
                  ? feed.heavyRotation
                  : feed.freshFinds;
          final hero = heroTracks.isEmpty ? null : heroTracks.first;
          return _OrbitDashboard(
            palette: palette,
            greeting: greeting,
            user: user,
            date: DateFormat('EEE · MMM d').format(DateTime.now()),
            feed: feed,
            playback: playback,
            hero: hero,
            onPlay: (track, tracks, index) => playAt(tracks, index),
            onDiscover: () => context.go('/discover'),
            onSearch: () => context.go('/search'),
            onLiked: () => context.go('/liked'),
            onRefresh: () => ref.invalidate(feedProvider),
            onPlayQueueIndex: (index) {
              if (playback.queue.isEmpty) return;
              unawaited(ref.read(playbackServiceProvider.notifier).playQueue(
                    playback.queue,
                    index,
                    sourceLabel: 'Orbit Queue',
                  ));
            },
            onPlayPause: () {
              final service = ref.read(playbackServiceProvider.notifier);
              if (playback.isPlaying) {
                unawaited(service.pause());
              } else {
                unawaited(service.playResume());
              }
            },
            onPrevious: () =>
                unawaited(ref.read(playbackServiceProvider.notifier).previous()),
            onNext: () =>
                unawaited(ref.read(playbackServiceProvider.notifier).next()),
            onShuffle: () =>
                unawaited(ref.read(playbackServiceProvider.notifier).toggleShuffle()),
            onRepeat: () =>
                unawaited(ref.read(playbackServiceProvider.notifier).cycleRepeat()),
          );
        },
      ),
    );
  }
}

class _OrbitDashboard extends StatelessWidget {
  const _OrbitDashboard({
    required this.palette,
    required this.greeting,
    required this.user,
    required this.date,
    required this.feed,
    required this.playback,
    required this.hero,
    required this.onPlay,
    required this.onDiscover,
    required this.onSearch,
    required this.onLiked,
    required this.onRefresh,
    required this.onPlayQueueIndex,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
  });

  final _OrbitPalette palette;
  final String greeting;
  final String user;
  final String date;
  final FeedData feed;
  final PlayerSnapshot playback;
  final GeneratedTrack? hero;
  final void Function(GeneratedTrack, List<GeneratedTrack>, int) onPlay;
  final VoidCallback onDiscover;
  final VoidCallback onSearch;
  final VoidCallback onLiked;
  final VoidCallback onRefresh;
  final ValueChanged<int> onPlayQueueIndex;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1100;
      final padding = constraints.maxWidth < 700 ? 16.0 : 28.0;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(padding, 22, padding, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OrbitHeader(
              palette: palette,
              greeting: greeting,
              user: user,
              date: date,
              onSearch: onSearch,
              onRefresh: onRefresh,
            ),
            const SizedBox(height: 22),
            _OrbitHero(
              palette: palette,
              track: hero,
              onPlay: hero == null
                  ? onDiscover
                  : () => onPlay(hero!, feed.quickPicks.isNotEmpty ? feed.quickPicks : [hero!], 0),
              onDiscover: onDiscover,
            ),
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TrackShelf(
                          palette: palette,
                          title: 'Made for your orbit',
                          subtitle: 'Quick picks, based on your listening',
                          tracks: feed.quickPicks,
                          emptyText: 'Your personalized picks will appear here.',
                          onPlay: onPlay,
                          onSeeAll: onDiscover,
                        ),
                        const SizedBox(height: 22),
                        _TrackListSection(
                          palette: palette,
                          title: 'Heavy rotation',
                          subtitle: 'The tracks you keep coming back to',
                          tracks: feed.heavyRotation,
                          onPlay: onPlay,
                          onLiked: onLiked,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 310,
                    child: _ListeningRail(
                      palette: palette,
                      feed: feed,
                      playback: playback,
                      onDiscover: onDiscover,
                      onPlayQueueIndex: onPlayQueueIndex,
                      onPlayPause: onPlayPause,
                      onPrevious: onPrevious,
                      onNext: onNext,
                      onShuffle: onShuffle,
                      onRepeat: onRepeat,
                    ),
                  ),
                ],
              )
            else ...[
              _TrackShelf(
                palette: palette,
                title: 'Made for your orbit',
                subtitle: 'Quick picks, based on your listening',
                tracks: feed.quickPicks,
                emptyText: 'Your personalized picks will appear here.',
                onPlay: onPlay,
                onSeeAll: onDiscover,
              ),
              const SizedBox(height: 22),
              _ListeningRail(
                palette: palette,
                feed: feed,
                playback: playback,
                onDiscover: onDiscover,
                onPlayQueueIndex: onPlayQueueIndex,
                onPlayPause: onPlayPause,
                onPrevious: onPrevious,
                onNext: onNext,
                onShuffle: onShuffle,
                onRepeat: onRepeat,
              ),
              const SizedBox(height: 22),
              _TrackListSection(
                palette: palette,
                title: 'Heavy rotation',
                subtitle: 'The tracks you keep coming back to',
                tracks: feed.heavyRotation,
                onPlay: onPlay,
                onLiked: onLiked,
              ),
            ],
            const SizedBox(height: 24),
            _TrackShelf(
              palette: palette,
              title: 'Fresh finds',
              subtitle: 'New directions worth following',
              tracks: feed.freshFinds,
              emptyText: 'New finds will show up when the feed has recommendations.',
              onPlay: onPlay,
              onSeeAll: onDiscover,
              accent: _OrbitPalette.violet,
            ),
            if (feed.becauseYouListened.isNotEmpty) ...[
              const SizedBox(height: 24),
              _TrackShelf(
                palette: palette,
                title: feed.becauseSeed.isNotEmpty
                    ? 'Because you listened to ${feed.becauseSeed}'
                    : 'A little further out',
                subtitle: 'Adjacent artists and sounds',
                tracks: feed.becauseYouListened,
                emptyText: 'Keep listening and we will find another thread.',
                onPlay: onPlay,
                onSeeAll: onDiscover,
                accent: _OrbitPalette.coral,
              ),
            ],
            const SizedBox(height: 24),
            _TastePanel(palette: palette, feed: feed, onDiscover: onDiscover),
          ],
        ),
      );
    });
  }
}

class _OrbitHeader extends StatelessWidget {
  const _OrbitHeader({
    required this.palette,
    required this.greeting,
    required this.user,
    required this.date,
    required this.onSearch,
    required this.onRefresh,
  });

  final _OrbitPalette palette;
  final String greeting;
  final String user;
  final String date;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LASTWAVE  /  ORBIT',
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '$greeting, $user.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(date, style: TextStyle(color: palette.muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _OrbitIconButton(
          palette: palette,
          icon: FluentIcons.search,
          label: 'Search music',
          onTap: onSearch,
        ),
        const SizedBox(width: 8),
        _OrbitIconButton(
          palette: palette,
          icon: FluentIcons.refresh,
          label: 'Refresh recommendations',
          onTap: onRefresh,
        ),
      ],
    );
  }
}

class _OrbitHero extends StatelessWidget {
  const _OrbitHero({
    required this.palette,
    required this.track,
    required this.onPlay,
    required this.onDiscover,
  });

  final _OrbitPalette palette;
  final GeneratedTrack? track;
  final VoidCallback onPlay;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final showArtwork = constraints.maxWidth > 600 && track != null;
      return Container(
        height: 244,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A2A53), Color(0xFF211B2C), Color(0xFF17151E)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -65,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _OrbitPalette.violet.withValues(alpha: 0.14),
                ),
              ),
            ),
            if (showArtwork)
              Positioned(
                right: 28,
                top: 26,
                bottom: 26,
                child: Transform.rotate(
                  angle: 0.035,
                  child: _OrbitArtwork(
                    url: track!.artworkUrl,
                    title: track!.name,
                    palette: palette,
                    size: 188,
                    radius: 18,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
              child: SizedBox(
                width: showArtwork ? constraints.maxWidth * 0.58 : constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: _OrbitPalette.lime,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'YOUR PERSONAL SOUNDTRACK',
                          style: TextStyle(
                            color: Color(0xFFD9D0EB),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.7,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      track == null ? 'Find your next\nrepeat obsession.' : 'Stay in your\nown frequency.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      track == null
                          ? 'Explore new sounds and build a mix around the mood you are in.'
                          : '${track!.name} · ${track!.artist}\nA starting point tuned to your listening.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFC5BDD2),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _OrbitActionButton(
                          label: track == null ? 'Explore music' : 'Play your mix',
                          icon: FluentIcons.play_solid,
                          onTap: onPlay,
                          background: _OrbitPalette.lime,
                          foreground: const Color(0xFF171A10),
                        ),
                        const SizedBox(width: 9),
                        _OrbitActionButton(
                          label: 'Discover',
                          icon: FluentIcons.chevron_right,
                          onTap: onDiscover,
                          background: Colors.white.withValues(alpha: 0.09),
                          foreground: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _TrackShelf extends StatelessWidget {
  const _TrackShelf({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.tracks,
    required this.emptyText,
    required this.onPlay,
    required this.onSeeAll,
    this.accent = _OrbitPalette.lime,
  });

  final _OrbitPalette palette;
  final String title;
  final String subtitle;
  final List<GeneratedTrack> tracks;
  final String emptyText;
  final void Function(GeneratedTrack, List<GeneratedTrack>, int) onPlay;
  final VoidCallback onSeeAll;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OrbitSectionHeader(
          palette: palette,
          title: title,
          subtitle: subtitle,
          action: tracks.isNotEmpty ? 'SEE ALL' : null,
          onAction: onSeeAll,
        ),
        const SizedBox(height: 12),
        if (tracks.isEmpty)
          _EmptyPanel(palette: palette, text: emptyText)
        else
          SizedBox(
            height: 193,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tracks.take(8).length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return _TrackCard(
                  palette: palette,
                  track: track,
                  accent: accent,
                  onTap: () => onPlay(track, tracks, index),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.palette,
    required this.track,
    required this.accent,
    required this.onTap,
  });

  final _OrbitPalette palette;
  final GeneratedTrack track;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _OrbitArtwork(
                  url: track.artworkUrl,
                  title: track.name,
                  palette: palette,
                  size: 132,
                  radius: 13,
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
                      ],
                    ),
                    child: const Icon(FluentIcons.play_solid, size: 14, color: Color(0xFF171A10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              track.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.text, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackListSection extends StatelessWidget {
  const _TrackListSection({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.tracks,
    required this.onPlay,
    required this.onLiked,
  });

  final _OrbitPalette palette;
  final String title;
  final String subtitle;
  final List<GeneratedTrack> tracks;
  final void Function(GeneratedTrack, List<GeneratedTrack>, int) onPlay;
  final VoidCallback onLiked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OrbitSectionHeader(
          palette: palette,
          title: title,
          subtitle: subtitle,
          action: 'LIKED SONGS',
          onAction: onLiked,
        ),
        const SizedBox(height: 8),
        if (tracks.isEmpty)
          _EmptyPanel(palette: palette, text: 'Your most-played tracks will collect here over time.')
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.outline),
            ),
            child: Column(
              children: [
                for (var i = 0; i < tracks.take(6).length; i++)
                  _TrackRow(
                    palette: palette,
                    track: tracks[i],
                    index: i,
                    onTap: () => onPlay(tracks[i], tracks, i),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.palette,
    required this.track,
    required this.index,
    required this.total,
    required this.onTap,
  });

  final _OrbitPalette palette;
  final GeneratedTrack track;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: TextStyle(color: palette.faint, fontSize: 10),
              ),
            ),
            _OrbitArtwork(url: track.artworkUrl, title: track.name, palette: palette, size: 42, radius: 8),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.text, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.muted, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(FluentIcons.play_solid, color: palette.muted, size: 12),
          ],
        ),
      ),
    );
  }
}

class _ListeningRail extends StatelessWidget {
  const _ListeningRail({
    required this.palette,
    required this.feed,
    required this.playback,
    required this.onDiscover,
    required this.onPlayQueueIndex,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
  });

  final _OrbitPalette palette;
  final FeedData feed;
  final PlayerSnapshot playback;
  final VoidCallback onDiscover;
  final ValueChanged<int> onPlayQueueIndex;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final current = playback.current;
    final durationMs = playback.duration.inMilliseconds;
    final progress = durationMs <= 0
        ? 0.0
        : (playback.position.inMilliseconds / durationMs).clamp(0.0, 1.0).toDouble();
    final repeatLabel = switch (playback.repeatMode) {
      RepeatMode.off => 'Repeat off',
      RepeatMode.all => 'Repeat all',
      RepeatMode.one => 'Repeat one',
    };
    final queueStart = playback.currentIndex < 0 ? 0 : playback.currentIndex + 1;
    final upcoming = playback.queue.skip(queueStart).take(4).toList();

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('LISTENING DESK', style: TextStyle(color: palette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
              ),
              Icon(FluentIcons.speakers, color: palette.muted, size: 15),
            ],
          ),
          const SizedBox(height: 14),
          if (current == null)
            Container(
              height: 122,
              width: double.infinity,
              decoration: BoxDecoration(
                color: palette.panelRaised,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.music_in_collection, color: palette.muted, size: 24),
                  const SizedBox(height: 9),
                  Text('Nothing playing yet', style: TextStyle(color: palette.text, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Pick a track to start your session', style: TextStyle(color: palette.muted, fontSize: 10)),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                _OrbitArtwork(url: current.artworkUrl, title: current.title, palette: palette, size: 78, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NOW PLAYING', style: TextStyle(color: palette.faint, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                      const SizedBox(height: 6),
                      Text(current.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.text, fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(current.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 10)),
                      const SizedBox(height: 7),
                      Text(playback.bitrateKbps > 0 ? '${playback.bitrateKbps} kbps' : 'AUDIO SESSION', style: TextStyle(color: palette.accent, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: palette.progressTrack),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(color: palette.accent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SmallTransport(palette: palette, icon: FluentIcons.previous, onTap: onPrevious, label: 'Previous'),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
                    child: Icon(playback.isPlaying ? FluentIcons.pause : FluentIcons.play_solid, color: palette.accentInk, size: 15),
                  ),
                ),
                const SizedBox(width: 14),
                _SmallTransport(palette: palette, icon: FluentIcons.next, onTap: onNext, label: 'Next'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuietControl(
                    palette: palette,
                    icon: FluentIcons.switcher_start_end,
                    label: playback.shuffleEnabled ? 'Shuffle on' : 'Shuffle off',
                    active: playback.shuffleEnabled,
                    onTap: onShuffle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuietControl(
                    palette: palette,
                    icon: FluentIcons.refresh,
                    label: repeatLabel,
                    active: playback.repeatMode != RepeatMode.off,
                    onTap: onRepeat,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 19),
          Row(
            children: [
              Expanded(child: Text('UP NEXT', style: TextStyle(color: palette.text, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4))),
              Text('${upcoming.length} TRACKS', style: TextStyle(color: palette.faint, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 9),
          if (upcoming.isEmpty)
            Text('Add a mix to build your queue.', style: TextStyle(color: palette.muted, fontSize: 11, height: 1.4))
          else
            for (var i = 0; i < upcoming.length; i++)
              _QueueRow(
                palette: palette,
                track: upcoming[i],
                index: queueStart + i,
                onTap: () => onPlayQueueIndex(queueStart + i),
              ),
          const SizedBox(height: 12),
          _OrbitActionButton(
            label: 'Open discovery',
            icon: FluentIcons.chevron_right,
            onTap: onDiscover,
            background: palette.panelRaised,
            foreground: palette.text,
            fullWidth: true,
          ),
          if (feed.tasteTags.isNotEmpty) ...[
            const SizedBox(height: 17),
            Text('YOUR CURRENT SIGNAL', style: TextStyle(color: palette.faint, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in feed.tasteTags.take(5))
                  _OrbitTag(palette: palette, label: tag),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.palette, required this.track, required this.index, required this.onTap});
  final _OrbitPalette palette;
  final PlayableTrack track;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _OrbitArtwork(url: track.artworkUrl, title: track.title, palette: palette, size: 34, radius: 7),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.text, fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 9)),
                ],
              ),
            ),
            Icon(FluentIcons.play_solid, color: palette.faint, size: 10),
          ],
        ),
      ),
    );
  }
}

class _TastePanel extends StatelessWidget {
  const _TastePanel({required this.palette, required this.feed, required this.onDiscover});
  final _OrbitPalette palette;
  final FeedData feed;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final tags = feed.tasteTags.take(10).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR SOUND, IN SIGNALS', style: TextStyle(color: palette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text('A taste profile that moves with you.', style: TextStyle(color: palette.text, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                const SizedBox(height: 6),
                Text('Use your current listening patterns as a launchpad, not a limit.', style: TextStyle(color: palette.muted, fontSize: 11, height: 1.4)),
                const SizedBox(height: 13),
                if (tags.isEmpty)
                  Text('Your sound map will grow as you listen.', style: TextStyle(color: palette.muted, fontSize: 11))
                else
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final tag in tags) _OrbitTag(palette: palette, label: tag)]),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _OrbitActionButton(
            label: 'Explore',
            icon: FluentIcons.chevron_right,
            onTap: onDiscover,
            background: palette.accent,
            foreground: palette.accentInk,
          ),
        ],
      ),
    );
  }
}

class _OrbitSectionHeader extends StatelessWidget {
  const _OrbitSectionHeader({required this.palette, required this.title, required this.subtitle, this.action, this.onAction});
  final _OrbitPalette palette;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: palette.text, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.35)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: palette.muted, fontSize: 10)),
            ],
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 1),
              child: Text(action!, style: TextStyle(color: palette.accent, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            ),
          ),
      ],
    );
  }
}

class _OrbitArtwork extends StatelessWidget {
  const _OrbitArtwork({required this.url, required this.title, required this.palette, required this.size, required this.radius});
  final String url;
  final String title;
  final _OrbitPalette palette;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? _ArtworkFallback(palette: palette)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ArtworkFallback(palette: palette),
              ),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.palette});
  final _OrbitPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_OrbitPalette.violet, Color(0xFF30243C), _OrbitPalette.coral],
        ),
      ),
      child: Icon(FluentIcons.music_in_collection, color: Colors.white.withValues(alpha: 0.88), size: 24),
    );
  }
}

class _OrbitActionButton extends StatelessWidget {
  const _OrbitActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.fullWidth = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(11)),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: foreground, size: 13),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
    return GestureDetector(onTap: onTap, child: fullWidth ? SizedBox(width: double.infinity, child: child) : child);
  }
}

class _OrbitIconButton extends StatelessWidget {
  const _OrbitIconButton({required this.palette, required this.icon, required this.label, required this.onTap});
  final _OrbitPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: palette.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: palette.outline)),
          child: Icon(icon, color: palette.text, size: 15),
        ),
      ),
    );
  }
}

class _SmallTransport extends StatelessWidget {
  const _SmallTransport({required this.palette, required this.icon, required this.onTap, required this.label});
  final _OrbitPalette palette;
  final IconData icon;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(width: 28, height: 34, child: Icon(icon, color: palette.text, size: 14)),
      ),
    );
  }
}

class _QuietControl extends StatelessWidget {
  const _QuietControl({required this.palette, required this.icon, required this.label, required this.active, required this.onTap});
  final _OrbitPalette palette;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: active ? palette.accent.withValues(alpha: 0.12) : palette.panelRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? palette.accent.withValues(alpha: 0.42) : palette.outline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? palette.accent : palette.muted, size: 11),
            const SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? palette.text : palette.muted, fontSize: 9, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

class _OrbitTag extends StatelessWidget {
  const _OrbitTag({required this.palette, required this.label});
  final _OrbitPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: palette.tagBackground, borderRadius: BorderRadius.circular(7), border: Border.all(color: palette.outline)),
      child: Text(label, style: TextStyle(color: palette.text, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.palette, required this.text});
  final _OrbitPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: palette.panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: palette.outline)),
      child: Text(text, style: TextStyle(color: palette.muted, fontSize: 11, height: 1.4)),
    );
  }
}

class _OrbitLoading extends StatelessWidget {
  const _OrbitLoading({required this.palette});
  final _OrbitPalette palette;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(width: width, height: height, decoration: BoxDecoration(color: palette.skeleton, borderRadius: BorderRadius.circular(8)));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        bar(130, 10), const SizedBox(height: 12), bar(280, 28), const SizedBox(height: 24),
        Container(height: 244, decoration: BoxDecoration(color: palette.panel, borderRadius: BorderRadius.circular(22))),
        const SizedBox(height: 24), bar(180, 18), const SizedBox(height: 12),
        Row(children: [for (var i = 0; i < 4; i++) Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: Container(height: 185, decoration: BoxDecoration(color: palette.panel, borderRadius: BorderRadius.circular(15))))) ]),
      ]),
    );
  }
}

class _OrbitError extends StatelessWidget {
  const _OrbitError({required this.palette, required this.onRetry});
  final _OrbitPalette palette;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: palette.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.outline)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(FluentIcons.info, color: palette.muted, size: 26),
          const SizedBox(height: 12),
          Text('Your feed did not load', style: TextStyle(color: palette.text, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Text('Your library and player remain available. Try refreshing recommendations.', textAlign: TextAlign.center, style: TextStyle(color: palette.muted, fontSize: 11, height: 1.4)),
          const SizedBox(height: 16),
          _OrbitActionButton(label: 'Try again', icon: FluentIcons.refresh, onTap: onRetry, background: palette.accent, foreground: palette.accentInk),
        ]),
      ),
    );
  }
}

class _OrbitPalette {
  const _OrbitPalette(this.dark);
  final bool dark;

  static const lime = Color(0xFFD9FF66);
  static const violet = Color(0xFFA78BFA);
  static const coral = Color(0xFFFF987D);

  Color get canvas => dark ? const Color(0xFF121016) : const Color(0xFFF6F3FA);
  Color get panel => dark ? const Color(0xFF1B1821) : const Color(0xFFFFFFFF);
  Color get panelRaised => dark ? const Color(0xFF25212D) : const Color(0xFFF0ECF5);
  Color get outline => dark ? const Color(0xFF302B39) : const Color(0xFFE1DBEA);
  Color get text => dark ? const Color(0xFFF6F1FC) : const Color(0xFF211C2B);
  Color get muted => dark ? const Color(0xFFADA5BB) : const Color(0xFF6D657A);
  Color get faint => dark ? const Color(0xFF82798F) : const Color(0xFF8B8299);
  Color get accent => dark ? lime : const Color(0xFF506600);
  Color get accentInk => dark ? const Color(0xFF171A10) : Colors.white;
  Color get progressTrack => dark ? const Color(0xFF393240) : const Color(0xFFE1DBE8);
  Color get tagBackground => dark ? const Color(0xFF25212D) : const Color(0xFFF7F4FA);
  Color get skeleton => dark ? const Color(0xFF24202B) : const Color(0xFFE9E3F0);
}
