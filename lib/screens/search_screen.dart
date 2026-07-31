import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/channel_art.dart';
import '../widgets/common.dart';
import '../widgets/premium_lock_modal.dart';
import 'player_screen.dart';

enum _HitKind { movie, channel }

class _SearchHit {
  final _HitKind kind;
  final String id;
  final String title;
  final String subtitle;
  final bool premium;
  final Movie? movie;
  final Channel? channel;

  const _SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.premium,
  }) : movie = null,
       channel = null;

  _SearchHit.movie(Movie m)
      : kind = _HitKind.movie,
        id = m.id,
        title = m.title,
        subtitle = '${m.genre} · ${m.year}',
        premium = m.premium,
        movie = m,
        channel = null;

  _SearchHit.channel(Channel c)
      : kind = _HitKind.channel,
        id = c.id,
        title = c.name,
        subtitle = c.program,
        premium = c.premium,
        movie = null,
        channel = c;
}

/// Full-screen search with live suggestions and filtering.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black26,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: const SearchScreen(),
        ),
      ),
    );
  }

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  List<_SearchHit> get _all {
    final state = context.read<AppState>();
    return [
      ...state.movies.map(_SearchHit.movie),
      ...state.channels.map(_SearchHit.channel),
    ];
  }

  static const _suggestions = [
    'Simba',
    'Football',
    'Katuni',
    'Tamthilia',
    'Wildlife',
    'Vichekesho',
    'Ligi Kuu',
    'Drama',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_SearchHit> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      // Default suggestions: mix of popular movies + live channels.
      final state = context.read<AppState>();
      return [
        ...state.newlyAdded.take(4).map(_SearchHit.movie),
        ...state.channels.take(4).map(_SearchHit.channel),
      ];
    }
    return _all.where((h) {
      final hay = '${h.title} ${h.subtitle} ${h.movie?.genres.join(' ') ?? ''} ${h.channel?.category ?? ''}'
          .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _playMovie(Movie m) {
    if (m.premium && !context.read<AppState>().subscribed) {
      PremiumLockModal.show(context);
      return;
    }
    context.read<AppState>().play(PlaybackSource.fromMovie(m));
    PlayerScreen.open(context);
  }

  void _playChannel(Channel c) {
    final state = context.read<AppState>();
    if (state.channelLocked(c)) {
      PremiumLockModal.show(context);
      return;
    }
    state.play(PlaybackSource.fromChannel(c));
    PlayerScreen.open(context);
  }

  void _openHit(_SearchHit hit) {
    if (hit.kind == _HitKind.movie && hit.movie != null) {
      _playMovie(hit.movie!);
    } else if (hit.channel != null) {
      _playChannel(hit.channel!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final hits = _filtered;
    final statusTop = MediaQuery.viewPaddingOf(context).top;

    return Material(
      color: AppColors.bg,
      child: Column(
        children: [
          SizedBox(height: statusTop),
          Padding(
            padding: EdgeInsets.fromLTRB(r.pageGutter, 10, r.pageGutter, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: r.sp(48),
                    decoration: BoxDecoration(
                      color: AppColors.section,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.shadow(blur: 16, y: 8, opacity: 0.14),
                      border: Border.all(color: const Color(0xFFD6E8F6)),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      style: AppTheme.body(r.sp(15), color: AppColors.textPrimary, weight: FontWeight.w600),
                      cursorColor: AppColors.green,
                      decoration: InputDecoration(
                        hintText: 'Tafuta filamu, chaneli…',
                        hintStyle: AppTheme.body(r.sp(14), color: AppColors.textHint, weight: FontWeight.w600),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: r.sp(4), vertical: r.sp(12)),
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.navy, size: r.sp(22)),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _ctrl.clear();
                                  setState(() => _query = '');
                                  _focus.requestFocus();
                                },
                                icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: r.sp(20)),
                              ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: r.sp(10)),
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Text(
                    'Funga',
                    style: AppTheme.body(r.sp(14), color: AppColors.navyMid, weight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          if (_query.trim().isEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(r.pageGutter, 6, r.pageGutter, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mapendekezo',
                  style: AppTheme.body(r.sp(12.5), color: AppColors.textHint, weight: FontWeight.w700),
                ),
              ),
            ),
            SizedBox(
              height: r.sp(40),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => SizedBox(width: r.sp(8)),
                itemBuilder: (_, i) {
                  final s = _suggestions[i];
                  return GestureDetector(
                    onTap: () {
                      _ctrl.text = s;
                      _ctrl.selection = TextSelection.collapsed(offset: s.length);
                      setState(() => _query = s);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: r.sp(14), vertical: r.sp(8)),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.section,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD6E8F6)),
                      ),
                      child: Text(s, style: AppTheme.body(r.sp(12.5), color: AppColors.navy, weight: FontWeight.w700)),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: r.sp(10)),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(r.pageGutter, 4, r.pageGutter, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _query.trim().isEmpty ? 'Maarufu sasa' : 'Matokeo (${hits.length})',
                style: AppTheme.body(r.sp(12.5), color: AppColors.textHint, weight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(
            child: hits.isEmpty
                ? Center(
                    child: Text(
                      'Hakuna matokeo',
                      style: AppTheme.body(r.sp(15), color: AppColors.textSecondary, weight: FontWeight.w600),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(r.pageGutter, 0, r.pageGutter, r.bottomNavClearance),
                    itemCount: hits.length,
                    separatorBuilder: (_, __) => SizedBox(height: r.sp(10)),
                    itemBuilder: (_, i) => _HitTile(hit: hits[i], onTap: () => _openHit(hits[i])),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  final _SearchHit hit;
  final VoidCallback onTap;
  const _HitTile({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final thumb = r.sp(56);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(r.sp(8)),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.shadow(blur: 18, y: 8, opacity: 0.12),
            border: Border.all(color: const Color(0xFFEEF5FB)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: thumb,
                  height: thumb,
                  child: hit.kind == _HitKind.movie && hit.movie != null
                      ? MovieArt(movie: hit.movie!, width: thumb, height: thumb, fit: BoxFit.cover)
                      : ChannelArt(channel: hit.channel!, width: thumb, height: thumb, fit: BoxFit.cover),
                ),
              ),
              SizedBox(width: r.sp(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(r.sp(14.5), color: AppColors.textPrimary, weight: FontWeight.w800),
                    ),
                    SizedBox(height: r.sp(3)),
                    Text(
                      hit.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(r.sp(12), color: AppColors.textSecondary, weight: FontWeight.w600),
                    ),
                    SizedBox(height: r.sp(4)),
                    Text(
                      hit.kind == _HitKind.movie ? 'Filamu' : 'Chaneli',
                      style: AppTheme.body(r.sp(11), color: AppColors.navyMid, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (hit.premium && hit.kind == _HitKind.channel)
                const PremiumChannelBadge()
              else if (hit.premium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('MALIPO', style: AppTheme.body(r.sp(10), color: AppColors.greenDark, weight: FontWeight.w800)),
                )
              else
                Icon(Icons.play_circle_fill_rounded, color: AppColors.green, size: r.sp(28)),
            ],
          ),
        ),
      ),
    );
  }
}
