// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class Ottplatformshomescreen extends StatefulWidget {
  const Ottplatformshomescreen({super.key});

  @override
  State<Ottplatformshomescreen> createState() => _OttplatformshomescreenState();
}

class _OttplatformshomescreenState extends State<Ottplatformshomescreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F171E),
      body: Stack(
        children: [
          RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    'https://deadline.com/wp-content/uploads/2025/11/Stranger-Things-5_33a02d.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    cacheWidth: 600,
                  ),
                ),

                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.3),
                          const Color(0xFF0F171E).withOpacity(0.8),
                          const Color(0xFF0F171E),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0F171E).withOpacity(0.9),
                          const Color(0xFF0F171E).withOpacity(0.4),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopNavigationBar(),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 40, bottom: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      _buildHeroSection(),
                      const SizedBox(height: 30),

                      const Text(
                        "Favorite Apps",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildAppsRow(),

                      const SizedBox(height: 30),

                      const Text(
                        "Play Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildMovieRow(),

                      const SizedBox(height: 30),

                      const Text(
                        "Youtube",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildMovieRow(reverse: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavigationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white70, size: 28),
          const SizedBox(width: 8),
          _buildNavItem("Search", false),
          const SizedBox(width: 20),
          _buildNavItem("Home", true),
          const SizedBox(width: 20),
          _buildNavItem("Discover", false),
          const SizedBox(width: 20),
          _buildNavItem("Apps", false),
          const Spacer(),
          const Icon(Icons.settings_outlined, color: Colors.white70, size: 24),
          const SizedBox(width: 20),
          const Text(
            "2:45",
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String title, bool isActive) {
    return _FocusableItem(
      childBuilder: (isFocused) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color:
                    isFocused
                        ? Colors.blueAccent
                        : (isActive ? Colors.white : Colors.white60),
                fontSize: 18,
                fontWeight:
                    isActive || isFocused ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isActive || isFocused)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: 20,
                color: isFocused ? Colors.blueAccent : Colors.white,
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeroSection() {
    return _FocusableItem(
      childBuilder: (isFocused) {
        return Container(
          decoration: BoxDecoration(
            border:
                isFocused
                    ? Border.all(color: Colors.blueAccent, width: 2)
                    : null,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Google Play",
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                "Pose",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Trending | Your truth if you dare",
                style: TextStyle(color: Colors.white60, fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppsRow() {
    final apps = [
      {
        "name": "XtraNet",
        "image":
            "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT2IoELoQYwVPC6QdGih1xBQ69TkgLWR_hH6A&s",
        "bg": Colors.white,
        "width": 160.0,
      },
      {
        "name": "YouTube",
        "image":
            "https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/YouTube_full-color_icon_%282017%29.svg/2560px-YouTube_full-color_icon_%282017%29.svg.png",
        "bg": Colors.white,
        "width": 160.0,
      },
      {
        "name": "Prime Video",
        "image":
            "https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Amazon_Prime_Video_logo.svg/2560px-Amazon_Prime_Video_logo.svg.png",
        "bg": const Color(0xFF00375F),
        "width": 160.0,
      },
      {
        "name": "Play Store",
        "image":
            "https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Google_Play_Store_badge_EN.svg/2560px-Google_Play_Store_badge_EN.svg.png",
        "bg": Colors.white,
        "width": 160.0,
      },
      {
        "name": "Twitch",
        "image": "https://pngimg.com/uploads/twitch/twitch_PNG6.png",
        "bg": const Color(0xFF9146FF),
        "width": 160.0,
      },
      {
        "name": "Google Play Movies",
        "image":
            "https://toppng.com/uploads/preview/if-you-own-an-android-tv-or-roku-device-google-has-google-play-movies-ico-11563219714ihplfjnjok.png",
        "bg": Colors.white,
        "width": 160.0,
      },
      {
        "name": "Home Media",
        "icon": Icons.home,
        "bg": const Color(0xFF00A8E1),
        "width": 120.0,
      },
      {
        "name": "Music",
        "image":
            "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/Youtube_Music_icon.svg/2048px-Youtube_Music_icon.svg.png",
        "bg": Colors.white,
        "width": 160.0,
      },
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: apps.length,
        itemBuilder: (context, index) {
          final app = apps[index];
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: _buildAppCard(app),
          );
        },
      ),
    );
  }

  Widget _buildAppCard(Map<String, dynamic> app) {
    return _FocusableItem(
      childBuilder: (isFocused) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: app['width'] as double? ?? 160.0,
          transform:
              isFocused
                  ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
                  : Matrix4.identity(),
          decoration: BoxDecoration(
            color: app['bg'] as Color,
            borderRadius: BorderRadius.circular(8),
            border:
                isFocused
                    ? Border.all(color: Colors.blueAccent, width: 3)
                    : null,
            boxShadow:
                isFocused
                    ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                    : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Center(
              child:
                  app.containsKey('icon')
                      ? Icon(
                        app['icon'] as IconData,
                        color: Colors.white,
                        size: 40,
                      )
                      : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 15.0,
                        ),
                        child: Image.network(
                          app['image'] as String,
                          fit: BoxFit.contain,
                          cacheWidth: 100,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              app['name'] as String,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovieRow({bool reverse = false}) {
    final images = [
      'https://www.hdwallpapers.in/download/all_characters_in_stranger_things_hd_stranger_things-1920x1080.jpg',
      'https://images.alphacoders.com/112/1121401.jpg',
      'https://wallpapercave.com/wp/wp8952362.jpg',
      'https://akamaividz2.zee5.com/image/upload/w_480,h_270,c_scale,f_webp,q_auto:eco/resources/0-0-1z5226610/list/rszImageTitle34a566e6643c420b9d7a87bf87efd43e.jpg',
      'https://cdn.wallpapersafari.com/98/42/ZDnJrl.jpg',
    ];

    if (reverse) {
      images.shuffle();
    }

    return SizedBox(
      height: 155,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 15),
            child: _buildMovieCard(images[index]),
          );
        },
      ),
    );
  }

  Widget _buildMovieCard(String imageUrl) {
    return _FocusableItem(
      childBuilder: (isFocused) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 220,
          transform:
              isFocused
                  ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
                  : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border:
                isFocused
                    ? Border.all(color: Colors.blueAccent, width: 3)
                    : null,
            boxShadow:
                isFocused
                    ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                    : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              imageUrl,
              width: 220,
              fit: BoxFit.cover,
              cacheWidth: 200,
            ),
          ),
        );
      },
    );
  }
}

class _FocusableItem extends StatefulWidget {
  final Widget Function(bool isFocused) childBuilder;
  final VoidCallback? onTap;

  // ignore: unused_element_parameter
  const _FocusableItem({required this.childBuilder, this.onTap});

  @override
  State<_FocusableItem> createState() => _FocusableItemState();
}

class _FocusableItemState extends State<_FocusableItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      child: Builder(
        builder: (context) {
          return InkWell(
            onTap: widget.onTap ?? () {},
            child: widget.childBuilder(_isFocused),
          );
        },
      ),
    );
  }
}
