import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/elite_background.dart';

class DesktopTasteScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;
  const DesktopTasteScreen({super.key, this.isOnboarding = false});

  @override
  ConsumerState<DesktopTasteScreen> createState() => _DesktopTasteScreenState();
}

class _DesktopTasteScreenState extends ConsumerState<DesktopTasteScreen> {
  final List<String> _selectedArtists = [];
  final List<String> _dynamicRelatedArtists = [];
  
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  bool _isSearching = false;
  bool _isLoadingSearch = false;
  List<String> _searchResults = [];

  String _currentTab = 'Bollywood / Hindi';

  final List<String> _tabs = [
    'Bollywood / Hindi',
    'English / Hollywood',
    'Punjabi',
    'South Indian',
  ];

  final Map<String, List<String>> _categoryArtists = {
    'Bollywood / Hindi': [
      'Arijit Singh',
      'Pritam',
      'Shreya Ghoshal',
      'A.R. Rahman',
      'Atif Aslam',
      'Jubin Nautiyal',
      'Neha Kakkar',
      'Kishore Kumar',
    ],
    'English / Hollywood': [
      'Taylor Swift',
      'The Weeknd',
      'Coldplay',
      'Ed Sheeran',
      'Billie Eilish',
      'Eminem',
      'Bruno Mars',
      'Dua Lipa',
    ],
    'Punjabi': [
      'Diljit Dosanjh',
      'AP Dhillon',
      'Sidhu Moose Wala',
      'Karan Aujla',
      'Guru Randhawa',
      'Badshah',
    ],
    'South Indian': [
      'Anirudh Ravichander',
      'Sid Sriram',
      'Devi Sri Prasad',
      'Ilaiyaraaja',
      'S.P. Balasubrahmanyam',
      'K.S. Chithra',
    ],
  };

  final Map<String, List<String>> _relatedArtistMapping = {
    'Arijit Singh': ['Atif Aslam', 'Shreya Ghoshal', 'Jubin Nautiyal', 'Pritam'],
    'Pritam': ['Arijit Singh', 'KK', 'Amit Trivedi', 'Sachin-Jigar'],
    'Shreya Ghoshal': ['Arijit Singh', 'Alka Yagnik', 'Lata Mangeshkar', 'A.R. Rahman'],
    'A.R. Rahman': ['Hariharan', 'Sid Sriram', 'Shreya Ghoshal', 'Amit Trivedi'],
    'Atif Aslam': ['Arijit Singh', 'Rahat Fateh Ali Khan', 'KK', 'Mohit Chauhan'],
    'Jubin Nautiyal': ['Arijit Singh', 'Neha Kakkar', 'Armaan Malik', 'Payal Dev'],
    'Neha Kakkar': ['Tony Kakkar', 'Badshah', 'Jubin Nautiyal', 'Asees Kaur'],
    'Taylor Swift': ['Selena Gomez', 'Olivia Rodrigo', 'Billie Eilish', 'Ariana Grande', 'Sabrina Carpenter'],
    'The Weeknd': ['Drake', 'Bruno Mars', 'Post Malone', 'Justin Bieber', 'Travis Scott'],
    'Coldplay': ['OneRepublic', 'Imagine Dragons', 'Maroon 5', 'Ed Sheeran', 'Keane'],
    'Ed Sheeran': ['Shawn Mendes', 'Bruno Mars', 'Coldplay', 'Justin Bieber', 'James Blunt'],
    'Billie Eilish': ['Lorde', 'Olivia Rodrigo', 'Finneas', 'Halsey', 'Lana Del Rey'],
    'Eminem': ['Dr. Dre', 'Snoop Dogg', '50 Cent', 'Jay-Z', 'Kanye West'],
    'Bruno Mars': ['Mark Ronson', 'Anderson .Paak', 'The Weeknd', 'Pharrell Williams'],
    'Dua Lipa': ['Bebe Rexha', 'Rita Ora', 'Ava Max', 'Miley Cyrus'],
    'Diljit Dosanjh': ['AP Dhillon', 'Karan Aujla', 'Sidhu Moose Wala', 'Amrinder Gill'],
    'AP Dhillon': ['Gurinder Gill', 'Shinda Kahlon', 'Intense', 'Diljit Dosanjh'],
    'Sidhu Moose Wala': ['Karan Aujla', 'Diljit Dosanjh', 'Amrit Maan', 'Prem Dhillon'],
    'Karan Aujla': ['Sidhu Moose Wala', 'Deep Jandu', 'Sandhu Surjit', 'Diljit Dosanjh'],
    'Badshah': ['Honey Singh', 'Raftaar', 'Divine', 'Harddy Sandhu'],
    'Anirudh Ravichander': ['Yuvan Shankar Raja', 'G.V. Prakash', 'Santhosh Narayanan', 'Devi Sri Prasad'],
    'Sid Sriram': ['Haricharan', 'Karthik', 'A.R. Rahman', 'Shreya Ghoshal'],
    'Devi Sri Prasad': ['Thaman S', 'Harris Jayaraj', 'Mani Sharma', 'Anirudh Ravichander'],
  };

  final Map<String, List<Color>> _artistGradients = {
    'Arijit Singh': const [Color(0xFFFA2D48), Color(0xFF7B61FF)],
    'Pritam': const [Color(0xFFFF9F0A), Color(0xFFFA2D48)],
    'Shreya Ghoshal': const [Color(0xFFBF5AF2), Color(0xFFFF6482)],
    'A.R. Rahman': const [Color(0xFF00D4FF), Color(0xFF7B61FF)],
    'Diljit Dosanjh': const [Color(0xFF30D158), Color(0xFF00D4FF)],
    'Taylor Swift': const [Color(0xFFFF6482), Color(0xFFBF5AF2)],
    'The Weeknd': const [Color(0xFF101010), Color(0xFFFA2D48)],
    'Coldplay': const [Color(0xFF0A84FF), Color(0xFF30D158)],
    'Ed Sheeran': const [Color(0xFFFF9F0A), Color(0xFF0A84FF)],
    'Billie Eilish': const [Color(0xFF30D158), Color(0xFF32D74B)],
    'Eminem': const [Color(0xFF1C1C1E), Color(0xFF6B6B78)],
    'Anirudh Ravichander': const [Color(0xFFFF375F), Color(0xFF5E5CE6)],
    'Sid Sriram': const [Color(0xFF64D2FF), Color(0xFFBF5AF2)],
  };

  final Map<String, String> _artistImages = {
    'Arijit Singh': 'https://c.saavncdn.com/artists/Arijit_Singh_004_20241118063717_150x150.jpg',
    'Pritam': 'https://c.saavncdn.com/artists/Pritam_Chakraborty-20170711073326_150x150.jpg',
    'Shreya Ghoshal': 'https://c.saavncdn.com/artists/Shreya_Ghoshal_007_20241101074144_150x150.jpg',
    'A.R. Rahman': 'https://c.saavncdn.com/artists/AR_Rahman_002_20210120084455_150x150.jpg',
    'Atif Aslam': 'https://c.saavncdn.com/artists/Atif_Aslam_500x500.jpg',
    'Jubin Nautiyal': 'https://c.saavncdn.com/artists/Jubin_Nautiyal_003_20231130204020_150x150.jpg',
    'Neha Kakkar': 'https://c.saavncdn.com/artists/Neha_Kakkar_007_20241212115832_150x150.jpg',
    'Kishore Kumar': 'https://c.saavncdn.com/artists/Kishore_Kumar_150x150.jpg',
    'Taylor Swift': 'https://c.saavncdn.com/artists/Taylor_Swift_003_20200226074119_150x150.jpg',
    'The Weeknd': 'https://c.saavncdn.com/artists/The_Weeknd_002_20241003071400_150x150.jpg',
    'Coldplay': 'https://c.saavncdn.com/artists/Coldplay_002_20241003070447_150x150.jpg',
    'Ed Sheeran': 'https://c.saavncdn.com/artists/Ed_Sheeran_002_20250625073038_150x150.jpg',
    'Billie Eilish': 'https://c.saavncdn.com/artists/Billie_Eilish_20190211151539_150x150.jpg',
    'Eminem': 'https://c.saavncdn.com/artists/Eminem_003_20240403152835_150x150.jpg',
    'Bruno Mars': 'https://c.saavncdn.com/artists/Bruno_Mars_003_20260324060413_150x150.jpg',
    'Dua Lipa': 'https://c.saavncdn.com/artists/Dua_Lipa_004_20231120090922_150x150.jpg',
    'Diljit Dosanjh': 'https://c.saavncdn.com/artists/Diljit_Dosanjh_005_20231025073054_150x150.jpg',
    'AP Dhillon': 'https://c.saavncdn.com/artists/AP_Dhillon_004_20251023102150_150x150.jpg',
    'Sidhu Moose Wala': 'https://c.saavncdn.com/artists/Sidhu_Moose_Wala_004_20250617183705_150x150.jpg',
    'Karan Aujla': 'https://c.saavncdn.com/artists/Karan_Aujla_003_20260218102828_150x150.jpg',
    'Guru Randhawa': 'https://c.saavncdn.com/artists/Guru_Randhawa_004_20250701125845_150x150.jpg',
    'Badshah': 'https://c.saavncdn.com/artists/Badshah_006_20241118064015_150x150.jpg',
    'Anirudh Ravichander': 'https://c.saavncdn.com/artists/Anirudh_Ravichander_003_20260121134149_150x150.jpg',
    'Sid Sriram': 'https://c.saavncdn.com/artists/Sid_Sriram_005_20240425180600_150x150.jpg',
    'Devi Sri Prasad': 'https://c.saavncdn.com/artists/Devi_Sri_Prasad_008_20250619062824_150x150.jpg',
    'Ilaiyaraaja': 'https://c.saavncdn.com/artists/Ilaiyaraaja_001_20251020081419_150x150.jpg',
    'S.P. Balasubrahmanyam': 'https://c.saavncdn.com/artists/S_P_Balasubrahmanyam_150x150.jpg',
    'K.S. Chithra': 'https://c.saavncdn.com/artists/K_S_Chithra_002_20190906071921_150x150.jpg',
  };

  final Set<String> _fetchingArtistImages = {};

  Future<void> _fetchArtistImage(String artistName) async {
    if (_artistImages.containsKey(artistName) || _fetchingArtistImages.contains(artistName) || artistName.isEmpty) return;
    _fetchingArtistImages.add(artistName);
    try {
      final api = ref.read(apiServiceProvider);
      final results = await api.searchArtists(artistName, limit: 1);
      if (results.isNotEmpty) {
        final img = results.first.image;
        if (img.isNotEmpty) {
          if (mounted) {
            setState(() {
              _artistImages[artistName] = img;
            });
          }
        }
      }
    } catch (_) {}
    _fetchingArtistImages.remove(artistName);
  }

  @override
  void initState() {
    super.initState();
    final currentFavs = ref.read(favoriteArtistsProvider);
    _selectedArtists.addAll(currentFavs);
    _updateDynamicSuggestionsForCurrentTab();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  List<Color> _getGradientForArtist(String name) {
    if (_artistGradients.containsKey(name)) {
      return _artistGradients[name]!;
    }
    final hash1 = name.hashCode;
    final hash2 = ('$name alt').hashCode;
    
    final hue1 = (hash1.abs() % 360).toDouble();
    final hue2 = (hash2.abs() % 360).toDouble();
    
    return [
      HSVColor.fromAHSV(1.0, hue1, 0.75, 0.85).toColor(),
      HSVColor.fromAHSV(1.0, hue2, 0.75, 0.7).toColor(),
    ];
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
    });
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _performSearch(val.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }
    
    setState(() {
      _isLoadingSearch = true;
      _isSearching = true;
    });
    
    try {
      final api = ref.read(apiServiceProvider);
      final songs = await api.searchSongs(query, limit: 20);
      final Set<String> artists = {};
      
      for (final song in songs) {
        final songArtists = song.artist.split(',');
        for (var a in songArtists) {
          final clean = a.trim();
          if (clean.isNotEmpty && clean.toLowerCase() != 'various artists') {
            artists.add(clean);
          }
        }
      }
      
      setState(() {
        _searchResults = artists.toList();
        _isLoadingSearch = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSearch = false;
        });
      }
    }
  }

  Future<List<String>> _fetchRelatedArtistsFromSongs(String artistName) async {
    try {
      final api = ref.read(apiServiceProvider);
      final songs = await api.searchSongs('$artistName hits', limit: 20);
      final Set<String> related = {};
      for (final song in songs) {
        final songArtists = song.artist.split(RegExp(r'[,&]'));
        for (var a in songArtists) {
          final clean = a.trim();
          if (clean.isNotEmpty && clean.toLowerCase() != artistName.toLowerCase() && clean.toLowerCase() != 'various artists') {
            related.add(clean);
          }
        }
      }
      return related.take(8).toList();
    } catch (_) {
      return [];
    }
  }

  void _onArtistSelected(String artistName) async {
    if (_selectedArtists.contains(artistName)) return;
    
    setState(() {
      _selectedArtists.add(artistName);
    });
    
    if (_relatedArtistMapping.containsKey(artistName)) {
      final related = _relatedArtistMapping[artistName]!;
      setState(() {
        for (final r in related) {
          if (!_selectedArtists.contains(r) && !_dynamicRelatedArtists.contains(r)) {
            _dynamicRelatedArtists.add(r);
          }
        }
      });
    }

    final dynamicRelated = await _fetchRelatedArtistsFromSongs(artistName);
    if (mounted) {
      setState(() {
        for (final r in dynamicRelated) {
          if (!_selectedArtists.contains(r) && !_dynamicRelatedArtists.contains(r)) {
            _dynamicRelatedArtists.add(r);
          }
        }
      });
    }
  }

  void _onArtistDeselected(String artistName) {
    setState(() {
      _selectedArtists.remove(artistName);
    });
  }

  void _onTabChanged(String tab) {
    setState(() {
      _currentTab = tab;
      _dynamicRelatedArtists.clear();
    });
    _updateDynamicSuggestionsForCurrentTab();
  }

  void _updateDynamicSuggestionsForCurrentTab() {
    final baseArtists = _categoryArtists[_currentTab] ?? [];
    for (final selected in _selectedArtists) {
      if (baseArtists.contains(selected) && _relatedArtistMapping.containsKey(selected)) {
        final related = _relatedArtistMapping[selected]!;
        for (final r in related) {
          if (!_selectedArtists.contains(r) && !_dynamicRelatedArtists.contains(r)) {
            _dynamicRelatedArtists.add(r);
          }
        }
      }
    }
  }

  Future<void> _saveAndContinue() async {
    if (_selectedArtists.length < 5) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );

      await FirebaseService.instance.saveFavoriteArtists(_selectedArtists);

      await ref.read(favoriteArtistsProvider.notifier).updateArtists(_selectedArtists);
      await ref.read(hasSelectedFavoritesProvider.notifier).setDone(true);

      ref.invalidate(homeDataProvider);
      ref.invalidate(suggestedSongsProvider);

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        if (widget.isOnboarding) {
          await StorageService().setOnboardingDone();
          await StorageService().setInteractiveOnboardingDone();
          if (context.mounted) context.go('/home');
        } else {
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.accent,
                content: Text(
                  'Taste customized successfully! Refreshing homepage...',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Sync failed: Unable to save preferences to Firebase. Details: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(dynamicPaletteProvider);
    final accent = palette.primary;

    final List<String> currentGridArtists = [
      ..._categoryArtists[_currentTab] ?? [],
      ..._dynamicRelatedArtists,
    ];

    final uniqueGridArtists = <String>[];
    for (final artist in currentGridArtists) {
      if (!uniqueGridArtists.contains(artist)) {
        uniqueGridArtists.add(artist);
      }
    }

    final isMinSelected = _selectedArtists.length >= 5;

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: RottyDynamicAuroraBackground(
        intensity: 0.8,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header ───
                Row(
                  children: [
                    if (!widget.isOnboarding) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Your Taste',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select 5 or more artists you love to personalize your music feed',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isOnboarding)
                      LiquidGlassButton(
                        accentColor: accent,
                        onTap: () async {
                          await StorageService().setOnboardingDone();
                          await StorageService().setInteractiveOnboardingDone();
                          await ref.read(hasSelectedFavoritesProvider.notifier).setDone(true);
                          if (context.mounted) context.go('/home');
                        },
                        child: Text(
                          'Skip Onboarding',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Search & Selected Chips Row ───
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search artists...',
                            hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.3)),
                            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30),
                            suffixIcon: _searchQuery.isNotEmpty || _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: Colors.white),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: _buildSelectedChipsHorizontal(accent),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Genre Tabs Row ───
                if (!_isSearching) ...[
                  Row(
                    children: _tabs.map((tab) {
                      final isSel = _currentTab == tab;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: LiquidGlassButton(
                          accentColor: accent,
                          isActive: isSel,
                          borderRadius: 20,
                          onTap: () => _onTabChanged(tab),
                          child: Text(
                            tab,
                            style: GoogleFonts.inter(
                              color: isSel ? accent : Colors.white.withValues(alpha: 0.6),
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // ─── Artist Grid ───
                Expanded(
                  child: _isLoadingSearch
                      ? _buildSearchResultsSkeleton()
                      : _buildArtistGrid(uniqueGridArtists, accent),
                ),
                const SizedBox(height: 20),

                // ─── Confirm Panel ───
                _buildConfirmPanel(isMinSelected, accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedChipsHorizontal(Color accent) {
    if (_selectedArtists.isEmpty) {
      return Container(
        height: 50,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.02),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Text(
          'No artists selected yet.',
          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
        ),
      );
    }
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedArtists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final artist = _selectedArtists[i];
          final gradient = _getGradientForArtist(artist);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: gradient),
                  ),
                  child: Center(
                    child: Text(
                      artist.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  artist,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _onArtistDeselected(artist),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                ),
              ],
            ),
          ).animate().scale(duration: 150.ms);
        },
      ),
    );
  }

  Widget _buildArtistGrid(List<String> artistsToShow, Color accent) {
    final list = _isSearching ? _searchResults : artistsToShow;
    if (list.isEmpty) {
      return Center(
        child: Text(
          _isSearching ? 'No artists found.' : 'Choose a tab to load artists.',
          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 0.95,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final artist = list[index];
        final isSelected = _selectedArtists.contains(artist);
        final gradient = _getGradientForArtist(artist);
        
        // Lazy-load artist image if not present
        if (!_artistImages.containsKey(artist)) {
          _fetchArtistImage(artist);
        }
        final img = _artistImages[artist] ?? '';

        return LiquidGlassCard(
          accentColor: accent,
          borderRadius: 16,
          padding: const EdgeInsets.all(12),
          onTap: () {
            if (isSelected) {
              _onArtistDeselected(artist);
            } else {
              _onArtistSelected(artist);
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? accent : Colors.white.withValues(alpha: 0.12),
                        width: isSelected ? 2 : 1,
                      ),
                      gradient: img.isEmpty
                          ? LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      image: img.isNotEmpty
                          ? DecorationImage(image: CachedNetworkImageProvider(img), fit: BoxFit.cover)
                          : null,
                    ),
                    child: img.isEmpty
                        ? Center(
                            child: Text(
                              artist.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
                  ),
                  if (isSelected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 8)],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ).animate().scale(duration: 150.ms),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                artist,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ).animate().fade(duration: 200.ms).scale(begin: const Offset(0.95, 0.95));
      },
    );
  }

  Widget _buildSearchResultsSkeleton() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 0.95,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 72, height: 72, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10)),
            const SizedBox(height: 12),
            Container(width: 50, height: 10, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: Colors.white10)),
          ],
        ),
      ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.05)),
    );
  }

  Widget _buildConfirmPanel(bool isMinSelected, Color accent) {
    return LiquidGlass(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      surfaceOpacity: 0.08,
      borderOpacity: 0.12,
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMinSelected
                  ? 'Great choices! Ready to set up your music dashboard.'
                  : 'Select at least ${5 - _selectedArtists.length} more artist(s) to continue.',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          MouseRegion(
            cursor: isMinSelected ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isMinSelected ? accent : Colors.white.withValues(alpha: 0.05),
                foregroundColor: isMinSelected ? Colors.white : Colors.white30,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: isMinSelected ? 8 : 0,
                shadowColor: isMinSelected ? accent.withValues(alpha: 0.5) : Colors.transparent,
              ),
              onPressed: isMinSelected ? _saveAndContinue : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Save & Continue',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
