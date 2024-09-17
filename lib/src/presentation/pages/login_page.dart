import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jplayer/resources/resources.dart';
import 'package:jplayer/src/data/params/params.dart';
import 'package:jplayer/src/presentation/widgets/widgets.dart';
import 'package:jplayer/src/providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  LoginPage({super.key, this.adSize = AdSize.banner,});

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
  ConsumerState<ConsumerStatefulWidget> createState() => LoginPageState();
}

class LoginPageState extends ConsumerState<LoginPage> {
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

  String? error;
  final _serverUrlInputController = 'https://tv.mowetent.com';
  final _emailInputController = 'music';
  final _passwordInputController = 'music';

  Future<void> signIn() async {
    final credentials = UserCredentials(
      username: _emailInputController.trim(),
      pw: _passwordInputController.trim(),
      serverUrl: _serverUrlInputController.trim(),
    );
    if (credentials.serverUrl.isEmpty || credentials.username.isEmpty) {
      setState(() {
        error = 'Server URL and login are required';
      });
      return;
    }

    if (!Uri.parse(credentials.serverUrl).isAbsolute) {
      setState(() {
        error =
            'Server URL is invalid. Should start with http/https and does not contain any path or query parameters';
      });
      return;
    }
    final resp = await ref.read(authProvider.notifier).login(credentials);
    if (resp != null) {
      await _interstitialAd?.show();
      setState(() {
        error = resp;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
    loadAd();
    _interstitialAd?.show();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(vertical: 36, horizontal: 48),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  maxWidth: 440,
                ),
                child: IntrinsicHeight(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event.logicalKey == LogicalKeyboardKey.enter) {
                        _interstitialAd?.show();
                        signIn();
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(Images.mainLogo),
                        const SizedBox(height: 63),
                        // _serverURLField(),
                        const SizedBox(height: 8),
                        // _loginField(),
                        const SizedBox(height: 8),
                        // _passwordField(),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Text(error!),
                        ],
                        const SizedBox(height: 63),
                        _signInButton(),
                        const SizedBox(height: 63),
                        // SizedBox(
                        //   width: _bannerAd.size.width.toDouble(),
                        //   height: _bannerAd.size.height.toDouble(),
                        //   child: AdWidget(ad: _bannerAd),
                        // ),
                      ],
                    ),

                  ),
                ),

              ),
            ),
          ),

        ),
      ),
    );
  }

  // Widget _serverURLField() => LabeledTextField(
  //       label: 'Server URL',
  //       keyboardType: TextInputType.url,
  //       controller: _serverUrlInputController,
  //       textInputAction: TextInputAction.next,
  //     );

  // Widget _loginField() => LabeledTextField(
  //       label: 'Login',
  //       keyboardType: TextInputType.text,
  //       controller: _emailInputController,
  //       textInputAction: TextInputAction.next,
  //     );

  // Widget _passwordField() => LabeledTextField(
  //       label: 'Password',
  //       controller: _passwordInputController,
  //       obscureText: true,
  //       keyboardType: TextInputType.visiblePassword,
  //       textInputAction: TextInputAction.done,
  //     );

  @override
  void dispose() {
    _bannerAd.dispose();
    _interstitialAd?.dispose();
    super.dispose();
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
        ));
  }

  Widget _signInButton() => InkWell(

        onTap: signIn,
        borderRadius: BorderRadius.circular(36),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 74),
          decoration: BoxDecoration(
            color: const Color(0xFF4571ED),
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                offset: const Offset(-1, 3),
                color: const Color(0xFF4571ED).withOpacity(0.7),
                spreadRadius: 6,
                blurRadius: 10,
              ),
            ],
          ),
          child: const Text(
            'Get Started',
            style: TextStyle(
              fontFamily: FontFamily.inter,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
}
