import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jplayer/src/config/routes.dart';
import 'package:jplayer/src/data/dto/item/item_dto.dart';
import 'package:jplayer/src/data/providers/providers.dart';
import 'package:jplayer/src/domain/providers/current_user_provider.dart';
import 'package:jplayer/src/presentation/utils/utils.dart';
import 'package:jplayer/src/presentation/widgets/widgets.dart';
import 'package:jplayer/src/providers/base_url_provider.dart';
import 'package:sliver_tools/sliver_tools.dart';

class ArtistPage extends ConsumerStatefulWidget {
  ArtistPage({required this.artist, super.key, this.adSize = AdSize.banner});
  final ItemDTO artist;

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
  ConsumerState<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends ConsumerState<ArtistPage> {
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
  final _titleKey = GlobalKey(debugLabel: 'title');
  List<ItemDTO> _albums = [];
  List<ItemDTO> _appearsOn = [];

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
    _getAlbums();
    _getAppearsOn();
    _scrollController.addListener(_onScroll);
    _loadAd();
    loadAd();
    _interstitialAd?.show();
  }

  Future<void> _getAppearsOn() async {
    final resp = await ref.read(jellyfinApiProvider).getAlbums(
      userId: ref.read(currentUserProvider)!.userId,
      libraryId: '',
      contributingArtistIds: widget.artist.id,
    );
    setState(() {
      _appearsOn = resp.data.items;
    });
  }

  Future<void> _getAlbums() async {
    final resp = await ref.read(jellyfinApiProvider).getAlbums(
      userId: ref.read(currentUserProvider)!.userId,
      libraryId: '',
      artistIds: [widget.artist.id],
    );
    setState(() {
      _albums = resp.data.items;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = Theme.of(context);
    _device = DeviceType.fromScreenSize(MediaQuery.sizeOf(context));
  }

  Widget get mobileView {
    return ScrollablePageScaffold(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          title: ValueListenableBuilder(
            valueListenable: _titleOpacity,
            builder: (context, opacity, child) => Transform.translate(
              offset: Offset(0, 8 - 8 * opacity),
              child: Opacity(
                opacity: opacity,
                child: child,
              ),
            ),
            child: Text(
              widget.artist.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          floating: true,
          pinned: true,
          // snap: true,
          expandedHeight: 250,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                if (widget.artist.backgropImageTags.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -60,
                    height: 340,
                    child: _headerImage(),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 60),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: _mainImage(),
                            ),
                          ),
                          Flexible(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  // SizedBox(
                                  //   width: _bannerAd.size.width.toDouble(),
                                  //   height: _bannerAd.size.height.toDouble(),
                                  //   child: AdWidget(ad: _bannerAd),
                                  // ),
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          key: _titleKey,
                                          widget.artist.name,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,),
                                        ),
                                      ),
                                      _playButton(),
                                    ],
                                  ),
                                  DefaultTextStyle(
                                    style: const TextStyle(fontSize: 14),
                                    child: _infoText(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18,),
                      SizedBox(
                        width: _bannerAd.size.width.toDouble(),
                        height: _bannerAd.size.height.toDouble(),
                        child: AdWidget(ad: _bannerAd),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ..._albumsWidgets(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_device.isMobile) {
      return mobileView;
    }
    return Scaffold(
      body: SafeArea(
        left: false,
        right: false,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            if (widget.artist.backgropImageTags.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                top: _device.isMobile ? -60 : 0,
                height: 340,
                child: _headerImage(),
              ),
            const Positioned(top: 4, left: 10, child: BackButton()),
            Padding(
              padding: EdgeInsets.only(
                left: _device.isMobile ? 20 : (_device.isTablet ? 64 : 40),
                top: _device.isMobile ? 60 : (_device.isTablet ? 140 : 238),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _mainImage(),
                        ),
                      ),
                      Flexible(
                        flex: 3,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: _device.isMobile
                                ? 16
                                : (_device.isTablet ? 64 : 40),
                          ),
                          child: SizedBox(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      widget.artist.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    _playButton(),
                                  ],
                                ),
                                DefaultTextStyle(
                                  style: TextStyle(
                                    fontSize: _device.isMobile ? 14 : 16,
                                  ),
                                  child: _infoText(),
                                ),
                                if (!_device.isMobile)
                                  SizedBox(
                                    height: _device.screenSize.height -
                                        (_device.isTablet ? 480 : 400),
                                    child: _albumsList(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: _bannerAd.size.width.toDouble(),
                        height: _bannerAd.size.height.toDouble(),
                        child: AdWidget(ad: _bannerAd),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
    _scrollController.dispose();
    _bannerAd.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  Widget _headerImage() => Container(
    decoration: BoxDecoration(
      image: DecorationImage(
        image: ref.read(imageProvider).backdropIp(
          tagId: widget.artist.backgropImageTags.firstOrNull,
          id: widget.artist.id,
        ),
        fit: BoxFit.fitWidth,
      ),
    ),
    foregroundDecoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _theme.scaffoldBackgroundColor.withOpacity(0),
          _theme.scaffoldBackgroundColor.withOpacity(1),
        ],
      ),
    ),
  );

  Widget _mainImage() => Image(
    image: ref.read(imageProvider).albumIP(
      tagId: widget.artist.imageTags['Primary'],
      id: widget.artist.id,
    ),
    width: 500,
  );

  Widget _infoText() => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Text(
      widget.artist.overview ??
          'This artist does not have any information.',
      maxLines: 5,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
      style: _theme.textTheme.bodySmall?.copyWith(
        fontSize: 14,
        height: 1.2,
      ),
    ),
  );

  Widget _playButton() => SizedBox(
    height: 48,
    child: PlayButton(onPressed: () {
      _interstitialAd?.show();
    },),
  );

  List<Widget> _albumsWidgets() {
    return [
      if (_albums.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, top: 8),
            child: Text(
              'Albums',
              style: TextStyle(
                fontSize: _device.isMobile ? 20 : 24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      if (_albums.isNotEmpty)
        SliverPadding(
          padding: EdgeInsets.only(
            top: 16,
            right: _device.isMobile ? 16 : (_device.isTablet ? 0 : 60),
            left: _device.isMobile ? 16 : (_device.isTablet ? 0 : 60),
            bottom: 16,
          ),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: _device.isMobile ? 200 : 160,
              mainAxisSpacing: 12,
              crossAxisSpacing: _device.isMobile ? 8 : 16,
              childAspectRatio: _device.isMobile ? 175 / 225 : 120 / 163,
            ),
            itemBuilder: (context, index) => AlbumView(
              showArtist: false,
              album: _albums[index],
              onTap: (album) {
                _interstitialAd?.show();
                final location = GoRouterState.of(context).fullPath;
                context.go(
                  '$location${Routes.album}',
                  extra: {
                    'album': album,
                    'artist': widget.artist,
                  },
                );
              },
              mainTextStyle: TextStyle(fontSize: _device.isMobile ? 16 : 14),
              subTextStyle: const TextStyle(fontSize: 14),
            ),
            itemCount: _albums.length,
          ),
        ),
      if (_appearsOn.isNotEmpty)
        SliverToBoxAdapter(
          child: Text(
            'Appears On',
            style: TextStyle(
              fontSize: _device.isMobile ? 20 : 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      SliverPadding(
        padding: EdgeInsets.only(
          top: 16,
          right: _device.isMobile ? 16 : (_device.isTablet ? 64 : 60),
          bottom: 16,
        ),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _device.isMobile ? 175 : 220,
            mainAxisSpacing: _device.isTablet ? 24 : 12,
            crossAxisSpacing: _device.isMobile ? 8 : 16,
            childAspectRatio: _device.isMobile ? 175 / 225 : 120 / 163,
          ),
          itemBuilder: (context, index) => AlbumView(
            showArtist: false,
            album: _appearsOn[index],
            onTap: (album) {
              _interstitialAd?.show();
              final location = GoRouterState.of(context).fullPath;
              context.go(
                '$location${Routes.album}',
                extra: {
                  'album': album,
                  'artist': widget.artist,
                },
              );
            },
            mainTextStyle: TextStyle(fontSize: _device.isMobile ? 16 : 14),
            subTextStyle: const TextStyle(fontSize: 14),
          ),
          itemCount: _appearsOn.length,
        ),
      ),
    ];
  }

  Widget _albumsList() => CustomScrollbar(
    controller: _scrollController,
    child: CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPinnedHeader(
          child: SizedBox.fromSize(
            size: const Size.fromHeight(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _theme.scaffoldBackgroundColor.withOpacity(1),
                    _theme.scaffoldBackgroundColor.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        ),
        ..._albumsWidgets(),
      ],
    ),
  );
}
