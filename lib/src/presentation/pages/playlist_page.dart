import 'dart:math';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jplayer/resources/j_player_icons.dart';
import 'package:jplayer/src/config/routes.dart';
import 'package:jplayer/src/data/dto/item/item_dto.dart';
import 'package:jplayer/src/data/dto/songs/songs_dto.dart';
import 'package:jplayer/src/data/providers/jellyfin_api_provider.dart';
import 'package:jplayer/src/data/providers/providers.dart';
import 'package:jplayer/src/data/services/image_service.dart';
import 'package:jplayer/src/domain/providers/current_user_provider.dart';
import 'package:jplayer/src/domain/providers/playback_provider.dart';
import 'package:jplayer/src/presentation/utils/utils.dart';
import 'package:jplayer/src/presentation/widgets/random_queue_button.dart';
import 'package:jplayer/src/presentation/widgets/widgets.dart';
import 'package:jplayer/src/providers/base_url_provider.dart';
import 'package:jplayer/src/providers/color_scheme_provider.dart';
import 'package:jplayer/src/providers/player_provider.dart';
import 'package:just_audio_background/just_audio_background.dart';

class PlaylistPage extends ConsumerStatefulWidget {
  PlaylistPage({required this.playlist, super.key, this.adSize = AdSize.banner});
  final ItemDTO playlist;
  final AdSize adSize;

  /// The AdMob ad unit to show.
  ///
  /// TODO: replace this test ad unit with your own ad unit
  final String adUnitId = Platform.isAndroid
  // Use this ad unit on Android...
      ? 'ca-app-pub-6028156998044233/1200979251'
  // ... or this one on iOS.
      : 'ca-app-pub-3940256099942544/2934735716';



  @override
  ConsumerState<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends ConsumerState<PlaylistPage> {

  InterstitialAd? _interstitialAd;

  // TODO: replace this test ad unit with your own ad unit.
  final adUnitId2 = Platform.isAndroid
      ? 'ca-app-pub-6028156998044233/9551876442'
      : 'ca-app-pub-6028156998044233/9551876442';


  /// The banner ad to show. This is `null` until the ad is actually loaded.
  late BannerAd _bannerAd;

  // TODO: replace this test ad unit with your own ad unit.
  final adUnitId = Platform.isAndroid
      ? 'ca-app-pub-6028156998044233/6135375615'
      : 'ca-app-pub-6028156998044233/6135375615';


  final _scrollController = ScrollController();
  final _titleOpacity = ValueNotifier<double>(0);
  late ValueNotifier<MediaItem?> _currentSong;
  final _titleKey = GlobalKey(debugLabel: 'title');
  List<SongDTO> songs = [];

  late final ImageService _imageService;

  late ThemeData _theme;
  late DeviceType _device;

  void _onScroll() {
    final titleContext = _titleKey.currentContext;

    if (titleContext?.mounted ?? false) {
      final scrollPosition = _scrollController.position;
      final scrollableContext = scrollPosition.context.notificationContext!;
      final scrollableRenderBox =
      scrollableContext.findRenderObject()! as RenderBox;
      final titleRenderBox = titleContext!.findRenderObject()! as RenderBox;
      final titlePosition = titleRenderBox.localToGlobal(
        Offset.zero,
        ancestor: scrollableRenderBox,
      );
      final titleHeight = titleContext.size!.height;
      final visibleFraction = (titlePosition.dy + titleHeight) / titleHeight;

      _titleOpacity.value = 1 - min(max(visibleFraction, 0), 1);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentSong = ValueNotifier<MediaItem?>(null);
    _imageService =
        ImageService(serverUrl: ref.read(baseUrlProvider.notifier).state!);
    _getSongs();
    ref.read(playerProvider).sequenceStateStream.listen((event) {
      if (event != null) {
        if (mounted) {
          _currentSong.value =
          event.sequence[event.currentIndex].tag as MediaItem;
          ref.read(imageSchemeProvider.notifier).state = _imageService.albumIP(
            id: widget.playlist.id,
            tagId: widget.playlist.imageTags['Primary'],
          );
        }
      }
    });
    _scrollController.addListener(_onScroll);
    _loadAd();
    loadAd();
    _interstitialAd?.show();
  }


  void _getSongs() {
    ref
        .read(jellyfinApiProvider)
        .getPlaylistSongs(
      userId: ref.read(currentUserProvider.notifier).state!.userId,
      playlistId: widget.playlist.id,
    )
        .then((value) {
      setState(() {
        final items = [...value.data.items]
          ..sort((a, b) => a.indexNumber.compareTo(b.indexNumber));
        songs = items;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = Theme.of(context);
    _device = DeviceType.fromScreenSize(MediaQuery.sizeOf(context));
  }

  ImageProvider get albumCover => _imageService.albumIP(
    id: widget.playlist.id,
    tagId: widget.playlist.imageTags['Primary'],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CupertinoNavigationBar(
                previousPageTitle: 'Playlists',
                backgroundColor: Colors.transparent,
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: _device.isMobile ? 16 : 30,
                ),
                middle: ValueListenableBuilder(
                  valueListenable: _titleOpacity,
                  builder: (context, opacity, child) => Transform.translate(
                    offset: Offset(0, 8 - 8 * opacity),
                    child: Opacity(
                      opacity: opacity,
                      child: child,
                    ),
                  ),
                  child: Text(
                    widget.playlist.name,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: _device.isMobile ? 14 : 20,
                      color: _theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: CustomScrollbar(
                  controller: _scrollController,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      if (_device.isDesktop)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(30, 0, 30, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Image(
                                  image: albumCover,
                                  height: 254,
                                ),
                                const SizedBox(width: 38),
                                // const SizedBox(height: 63),
                                // SizedBox(
                                //   width: _bannerAd.size.width.toDouble(),
                                //   height: _bannerAd.size.height.toDouble(),
                                //   child: AdWidget(ad: _bannerAd),
                                // ),
                                Expanded(child: _albumPanel()),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: _device.isMobile ? 16 : 30,
                          ),
                          sliver: SliverPersistentHeader(
                            pinned: true,
                            delegate: _FadeOutImageDelegate(
                              image: albumCover,
                              isMobile: _device.isMobile,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.only(
                            left: _device.isMobile ? 16 : 30,
                            top: _device.isMobile ? 15 : 35,
                            right: _device.isMobile ? 16 : 30,
                            bottom: _device.isMobile ? 0 : 18,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _albumPanelMobile(),
                          ),
                        ),
                      ],
                      SliverList.builder(
                        itemBuilder: (context, index) => ValueListenableBuilder(
                          valueListenable: _currentSong,
                          builder: (context, item, other) {
                            final song = songs[index];
                            return PlayerSongView(
                              song: song,
                              isPlaying: item != null && song.id == item.id,
                              onTap: (song) => ref
                                  .read(playbackProvider.notifier)
                                  .play(song, songs, widget.playlist),
                              position: index + 1,
                              onLikePressed: (song) async {
                                final api = ref.read(jellyfinApiProvider);
                                final callback = song.songUserData.isFavorite
                                    ? api.removeFavorite
                                    : api.saveFavorite;
                                await callback.call(
                                  userId: ref.read(currentUserProvider)!.userId,
                                  itemId: song.id,
                                );
                                _getSongs();
                              },
                              optionsBuilder: (context) => [
                                PopupMenuItem(
                                  onTap: () async {
                                    final api = ref.read(jellyfinApiProvider);
                                    if (song.playlistItemId == null) {
                                      const snackBar = SnackBar(
                                        backgroundColor: Colors.black87,
                                        content: Text(
                                          'Uff! Something went wrong...',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(snackBar);
                                    } else {
                                      await api.removePlaylistItem(
                                          playlistId: widget.playlist.id,
                                          entryIds: song.playlistItemId!,);
                                      const snackBar = SnackBar(
                                        backgroundColor: Colors.black87,
                                        content: Text(
                                          'Successfully removed item from playlist',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      );
                                      _getSongs();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(snackBar);
                                      }
                                    }
                                  },
                                  child: const Text('Remove from playlist'),
                                ),
                                if (song.albumArtists?.isNotEmpty ?? false)
                                  PopupMenuItem(
                                    onTap: () async {
                                      final location = GoRouterState.of(context)
                                          .matchedLocation;
                                      final res = await ref
                                          .read(jellyfinApiProvider)
                                          .searchArtists(
                                        userId: ref
                                            .read(currentUserProvider)!
                                            .userId,
                                        searchTerm:
                                        song.albumArtists!.first.name,
                                      );
                                      if (context.mounted) {
                                        context.go(
                                          '$location${Routes.artist}',
                                          extra: {
                                            'playlist': widget.playlist,
                                            'artist': res.data.items.first,
                                          },
                                        );
                                      }
                                    },
                                    child: const Text('Go to artist'),
                                  ),
                                if (song.albumName != null)
                                  PopupMenuItem(
                                    onTap: () async {
                                      final location = GoRouterState.of(context)
                                          .matchedLocation;
                                      final res = await ref
                                          .read(jellyfinApiProvider)
                                          .searchAlbums(
                                        userId: ref
                                            .read(currentUserProvider)!
                                            .userId,
                                        searchTerm: song.albumName!,
                                      );
                                      if (context.mounted) {
                                        context.go(
                                          '$location${Routes.album}',
                                          extra: {
                                            'playlist': widget.playlist,
                                            'album': res.data.items.first,
                                          },
                                        );
                                      }
                                    },
                                    child: const Text('Go to album'),
                                  ),
                              ],
                            );
                          },
                        ),
                        itemCount: songs.length,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Loads a banner ad.
  void _loadAd() {
    final bannerAd = BannerAd(
      size: widget.adSize,
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        // Called when an ad is successfully received.
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
          });
        },
        // Called when an ad request failed.
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    );

    // Start loading.
    bannerAd.load();
  }

  /// Loads a interstitial ad.
  void loadAd() {
    InterstitialAd.load(
      adUnitId: adUnitId2,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        // Called when an ad is successfully received.
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          // Keep a reference to the ad so you can show it later.
          _interstitialAd = ad;
        },
        // Called when an ad request failed.
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('InterstitialAd failed to load: $error');
        },
      ),);
  }



  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
    _titleOpacity.dispose();
    _currentSong.dispose();
    _bannerAd.dispose();
    _interstitialAd?.dispose();
  }

  Widget _albumPanelMobile() => IconTheme(
    data: _theme.iconTheme.copyWith(size: _device.isMobile ? 24 : 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                widget.playlist.name,
                key: _titleKey,
                style: TextStyle(
                  fontSize: _device.isMobile ? 18 : 32,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 63),
        SizedBox(
          width: _bannerAd.size.width.toDouble(),
          height: _bannerAd.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd),
        ),
        Text(widget.playlist.albumArtist ?? ''),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _albumDetails(
              duration: widget.playlist.duration,
              soundsCount: songs.length,
              albumArtist: songs.isNotEmpty ? songs.first.albumArtist : '',
              year: widget.playlist.productionYear,
              divider: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Offstage(
                  offstage: _device.isMobile,
                  child: const Icon(Icons.circle, size: 4),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // _downloadAlbumButton(),
                // const RandomQueueButton(),
                SizedBox.square(
                  dimension: _device.isMobile ? 38 : 48,
                  child: _playAlbumButton(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  Widget _albumPanel() => IconTheme(
    data: _theme.iconTheme.copyWith(size: _device.isMobile ? 24 : 28),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.playlist.name,
                      key: _titleKey,
                      style: TextStyle(
                        fontSize: _device.isMobile ? 18 : 32,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              Text(widget.playlist.albumArtist ?? ''),
              Row(
                children: [
                  _albumDetails(
                    duration: widget.playlist.duration,
                    soundsCount: songs.length,
                    albumArtist:
                    songs.isNotEmpty ? songs.first.albumArtist : '',
                    year: widget.playlist.productionYear,
                    divider: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Offstage(
                        offstage: _device.isMobile,
                        child: const Icon(Icons.circle, size: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: _device.isDesktop ? 35 : 32),
        if (_device.isDesktop)
          Container()
        // StreamBuilder<PlayerState>(
        //   stream: ref.read(playerProvider).playerStateStream,
        //   builder: (context, snapshot) {
        //     return Expanded(
        //       child: Row(
        //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //         children: [
        //           SizedBox.square(
        //             dimension: 65,
        //             child: _playAlbumButton(),
        //           ),
        //           _downloadAlbumButton(),
        //         ],
        //       ),
        //     );
        //   },
        // )
        else
          Wrap(
            spacing: _device.isMobile ? 6 : 32,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _downloadAlbumButton(),
              const RandomQueueButton(),
              SizedBox.square(
                dimension: _device.isMobile ? 40 : 48,
                child: _playAlbumButton(),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _playAlbumButton() => PlayButton(
    onPressed: () {
      _interstitialAd?.show();
    },
  );

  Widget _downloadAlbumButton() => IconButton(
    onPressed: () {},
    icon: const Icon(JPlayer.download),
  );

  Widget _albumDetails({
    required Duration duration,
    required int soundsCount,
    int? year,
    String? albumArtist,
    Widget divider = const SizedBox.shrink(),
  }) {
    final durationInSeconds = duration.inSeconds;
    final hours = durationInSeconds ~/ Duration.secondsPerHour;
    final minutes = (durationInSeconds - hours * Duration.secondsPerHour) ~/
        Duration.secondsPerMinute;
    final seconds = durationInSeconds % Duration.secondsPerMinute;

    return DefaultTextStyle(
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(JPlayer.clock, size: 14),
          ),
          Text(
            [
              if (hours > 0) hours.toString().padLeft(2, '0'),
              minutes.toString().padLeft(2, '0'),
              seconds.toString().padLeft(2, '0'),
            ].join(':'),
          ),
          divider,
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(JPlayer.music, size: 14),
          ),
          Text('$soundsCount songs'),
          if (year != null) ...[
            divider,
            Text(
              year.toString(),
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ],
        ],
      ),
    );
  }
}

class _FadeOutImageDelegate extends SliverPersistentHeaderDelegate {
  const _FadeOutImageDelegate({
    required this.image,
    required this.isMobile,
  });

  final ImageProvider image;
  final bool isMobile;

  @override
  double get maxExtent => isMobile ? 182 : 299;

  @override
  double get minExtent => 0;

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    return Image(
      image: image,
      height: max(maxExtent - shrinkOffset, 0),
      opacity: AlwaysStoppedAnimation(
        max((maxExtent - shrinkOffset * 1.5) / maxExtent, 0),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FadeOutImageDelegate oldDelegate) =>
      image != oldDelegate.image || isMobile != oldDelegate.isMobile;
}
