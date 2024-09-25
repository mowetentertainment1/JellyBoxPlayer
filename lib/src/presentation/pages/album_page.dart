import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jplayer/resources/j_player_icons.dart';
import 'package:jplayer/src/data/dto/item/item_dto.dart';
import 'package:jplayer/src/data/dto/songs/songs_dto.dart';
import 'package:jplayer/src/data/providers/jellyfin_api_provider.dart';
import 'package:jplayer/src/data/services/image_service.dart';
import 'package:jplayer/src/domain/providers/current_user_provider.dart';
import 'package:jplayer/src/domain/providers/playback_provider.dart';
import 'package:jplayer/src/domain/providers/playlists_provider.dart';
import 'package:jplayer/src/presentation/utils/utils.dart';
import 'package:jplayer/src/presentation/widgets/random_queue_button.dart';
import 'package:jplayer/src/presentation/widgets/widgets.dart';
import 'package:jplayer/src/providers/base_url_provider.dart';
import 'package:jplayer/src/providers/color_scheme_provider.dart';
import 'package:jplayer/src/providers/player_provider.dart';
import 'package:just_audio_background/just_audio_background.dart';


class AlbumPage extends ConsumerStatefulWidget {
  AlbumPage({required this.album, super.key, this.adSize = AdSize.banner});
  final ItemDTO album;

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
  ConsumerState<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends ConsumerState<AlbumPage> {
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

  Future<void> _onAddToPlaylistPressed(SongDTO song) async {
    ItemDTO? playlist;

    if (_device.isDesktop) {
      playlist = await showAdaptiveDialog<ItemDTO>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: _availablePlaylistsList(),
        ),
      );
    } else {
      playlist = await showModalBottomSheet<ItemDTO>(
          backgroundColor: Colors.grey[800],
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          context: context,
          useRootNavigator: true,
          clipBehavior: Clip.antiAlias,
          builder: (context) => _availablePlaylistsList(
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),);
    }

    if (playlist != null) {
      await ref.read(jellyfinApiProvider).addPlaylistItems(
        playlistId: playlist.id,
        userId: ref.read(currentUserProvider)!.userId,
        entryIds: song.id,
      );
      const snackBar = SnackBar(
        backgroundColor: Colors.black87,
        content: Text(
          'Successfully added item to playlist',
          style: TextStyle(color: Colors.white),
        ),
      );
      _getSongs();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
    await _interstitialAd?.show();
  }

  void _onScroll() {
    final titleContext = _titleKey.currentContext;

    if (titleContext?.mounted ?? false) {
      final scrollPosition = _scrollController.position;
      final scrollableContext = scrollPosition.context.notificationContext!;
      final scrollableRenderBox = scrollableContext.findRenderObject()! as RenderBox;
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
    _imageService = ImageService(serverUrl: ref.read(baseUrlProvider.notifier).state!);
    _getSongs();
    ref.read(playerProvider).sequenceStateStream.listen((event) {
      if (event != null) {
        if (mounted) {
          _currentSong.value = event.sequence[event.currentIndex].tag as MediaItem;
          ref.read(imageSchemeProvider.notifier).state = _imageService.albumIP(
            id: widget.album.id,
            tagId: widget.album.imageTags['Primary'],
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
        .getSongs(
      userId: ref.read(currentUserProvider)!.userId,
      albumId: widget.album.id,
    )
        .then((value) {
      setState(() {
        final items = [...value.data.items]..sort((a, b) => a.indexNumber.compareTo(b.indexNumber));
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

  ImageProvider get albumCover => _imageService.albumIP(id: widget.album.id, tagId: widget.album.imageTags['Primary']);

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
                previousPageTitle: 'Albums',
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
                    widget.album.name,
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
                              onTap: (song) => ref.read(playbackProvider.notifier).play(song, songs, widget.album),
                              position: index + 1,
                              onLikePressed: (song) async {
                                final api = ref.read(jellyfinApiProvider);
                                final callback = song.songUserData.isFavorite ? api.removeFavorite : api.saveFavorite;
                                await callback.call(
                                  userId: ref.read(currentUserProvider)!.userId,
                                  itemId: song.id,
                                );
                                _getSongs();
                                await _interstitialAd?.show();
                              },
                              optionsBuilder: (context) => [
                                PopupMenuItem(
                                  onTap: () => _onAddToPlaylistPressed(song),
                                  child: const Text('Add to playlist'),
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
        SizedBox(
          width: _bannerAd.size.width.toDouble(),
          height: _bannerAd.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Flexible(
              child: Text(
                widget.album.name,
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
        Text(widget.album.albumArtist ?? ''),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _albumDetails(
              duration: widget.album.duration,
              soundsCount: songs.length,
              albumArtist: songs.isNotEmpty ? songs.first.albumArtist : '',
              year: widget.album.productionYear,
              divider: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Offstage(
                  offstage: _device.isMobile,
                  child: const Icon(Icons.circle, size: 4),
                ),
              ),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
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
                  const SizedBox(height: 63),
                  Flexible(
                    child: Text(
                      widget.album.name,
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
              Text(widget.album.albumArtist ?? ''),
              Row(
                children: [
                  _albumDetails(
                    duration: widget.album.duration,
                    soundsCount: songs.length,
                    albumArtist: songs.isNotEmpty ? songs.first.albumArtist : '',
                    year: widget.album.productionYear,
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
    final minutes = (durationInSeconds - hours * Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
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

  Widget _availablePlaylistsList({EdgeInsets padding = EdgeInsets.zero}) {
    return Consumer(
      builder: (context, ref, child) {
        final data = ref.watch(playlistsProvider);
        final formKey = GlobalKey<FormState>();
        if (data.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(_device.isDesktop ? 6 : 0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: _device.isDesktop ? 380 : double.infinity,
              child: Flex(
                mainAxisSize: MainAxisSize.min,
                direction: Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Add to playlist',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _interstitialAd?.show();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.only(top: 10)),
                  Form(
                    key: formKey,
                    child: DropdownButtonFormField<ItemDTO>(
                      onSaved: (ItemDTO? value) {
                        Navigator.of(context).pop(value);
                      },
                      hint: Text(
                        _device.isMobile ? 'Tap to find playlist' : 'Click to find playlist',
                        style: const TextStyle(fontSize: 14),
                      ),
                      onChanged: (ItemDTO? item) {},
                      items: data.value.items.map<DropdownMenuItem<ItemDTO>>(
                            (ItemDTO item) {
                          return DropdownMenuItem<ItemDTO>(value: item, child: Text(item.name));
                        },
                      ).toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 36),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () {
                            _interstitialAd?.show();
                            if (formKey.currentState!.validate()) {
                              formKey.currentState!.save();
                            }
                          },
                          child: const Text('Add to playlist'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // return ListBody(
        //   children: [
        //     SizedBox(height: padding.top),
        //     for (final playlist in data.value.items)
        //       SimpleListTile(
        //         onTap: () => Navigator.of(context).pop(playlist),
        //         padding: padding.copyWith(top: 6, bottom: 6),
        //         title: Text(
        //           playlist.name,
        //           style: const TextStyle(
        //             fontSize: 16,
        //             fontWeight: FontWeight.w500,
        //           ),
        //         ),
        //       ),
        //     SizedBox(height: padding.bottom),
        //   ],
        // );
      },
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
  bool shouldRebuild(covariant _FadeOutImageDelegate oldDelegate) => image != oldDelegate.image || isMobile != oldDelegate.isMobile;
}
