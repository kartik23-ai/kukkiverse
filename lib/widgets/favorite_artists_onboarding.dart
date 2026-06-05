import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../core/theme/app_colors.dart';


class FavoriteArtistsOnboarding extends StatefulWidget {
  final VoidCallback onCompleted;
  const FavoriteArtistsOnboarding({super.key, required this.onCompleted});

  @override
  State<FavoriteArtistsOnboarding> createState() => _FavoriteArtistsOnboardingState();
}

class _FavoriteArtistsOnboardingState extends State<FavoriteArtistsOnboarding> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedArtists = {};
  String _selectedLanguage = 'All';
  bool _isSaving = false;

  final List<String> _languages = ['All', 'Hindi', 'English', 'Punjabi', 'Telugu', 'Tamil'];

  // Static artist list with their metadata
  final List<Map<String, String>> _artists = [
    // Hindi
    {'name': 'Arijit Singh', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Arijit_Singh_007_20230711171807_500x500.jpg'},
    {'name': 'Pritam', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Pritam_100_20230811120049_500x500.jpg'},
    {'name': 'A.R. Rahman', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/A_R_Rahman_004_20230605175510_500x500.jpg'},
    {'name': 'Shreya Ghoshal', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Shreya_Ghoshal_004_20230607172828_500x500.jpg'},
    {'name': 'Jubin Nautiyal', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Jubin_Nautiyal_005_20230612140833_500x500.jpg'},
    {'name': 'Anuv Jain', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Anuv_Jain_500x500.jpg'},
    {'name': 'Atif Aslam', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Atif_Aslam_500x500.jpg'},
    {'name': 'Neha Kakkar', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Neha_Kakkar_006_20200814112635_500x500.jpg'},

    // English
    {'name': 'Taylor Swift', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Taylor_Swift_007_20230619172242_500x500.jpg'},
    {'name': 'Ed Sheeran', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Ed_Sheeran_007_20230619183424_500x500.jpg'},
    {'name': 'The Weeknd', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/The_Weeknd_005_20230310153835_500x500.jpg'},
    {'name': 'Billie Eilish', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Billie_Eilish_005_20230303173752_500x500.jpg'},
    {'name': 'Justin Bieber', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Justin_Biber_500x500.jpg'},
    {'name': 'Coldplay', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Coldplay_500x500.jpg'},
    {'name': 'Drake', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Drake_500x500.jpg'},
    {'name': 'Bruno Mars', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Bruno_Mars_500x500.jpg'},

    // Punjabi
    {'name': 'Diljit Dosanjh', 'lang': 'Punjabi', 'image': 'https://c.saavncdn.com/artists/Diljit_Dosanjh_004_20221004175317_500x500.jpg'},
    {'name': 'AP Dhillon', 'lang': 'Punjabi', 'image': 'https://c.saavncdn.com/artists/AP_Dhillon_500x500.jpg'},
    {'name': 'Karan Aujla', 'lang': 'Punjabi', 'image': 'https://c.saavncdn.com/artists/Karan_Aujla_007_20230713170701_500x500.jpg'},
    {'name': 'Sidhu Moose Wala', 'lang': 'Punjabi', 'image': 'https://c.saavncdn.com/artists/Sidhu_Moose_Wala_004_20230607172031_500x500.jpg'},
    {'name': 'Guru Randhawa', 'lang': 'Punjabi', 'image': 'https://c.saavncdn.com/artists/Guru_Randhawa_007_20230713170327_500x500.jpg'},
    {'name': 'Jass Manak', 'lang': 'Punjabi', 'image': 'https://c.saavncdn.com/artists/Jass_Manak_007_20230713170014_500x500.jpg'},

    // Telugu
    {'name': 'Sid Sriram', 'lang': 'Telugu', 'image': 'https://c.saavncdn.com/artists/Sid_Sriram_007_20230623145455_500x500.jpg'},
    {'name': 'Devi Sri Prasad', 'lang': 'Telugu', 'image': 'https://c.saavncdn.com/artists/Devi_Sri_Prasad_500x500.jpg'},
    {'name': 'S. Thaman', 'lang': 'Telugu', 'image': 'https://c.saavncdn.com/artists/S_Thaman_004_20220614134444_500x500.jpg'},
    {'name': 'Anirudh Ravichander', 'lang': 'Telugu', 'image': 'https://c.saavncdn.com/artists/Anirudh_Ravichander_004_20230531182245_500x500.jpg'},

    // Tamil
    {'name': 'Anirudh Ravichander', 'lang': 'Tamil', 'image': 'https://c.saavncdn.com/artists/Anirudh_Ravichander_004_20230531182245_500x500.jpg'},
    {'name': 'A.R. Rahman', 'lang': 'Tamil', 'image': 'https://c.saavncdn.com/artists/A_R_Rahman_004_20230605175510_500x500.jpg'},
    {'name': 'Sid Sriram', 'lang': 'Tamil', 'image': 'https://c.saavncdn.com/artists/Sid_Sriram_007_20230623145455_500x500.jpg'},
    {'name': 'Yuvan Shankar Raja', 'lang': 'Tamil', 'image': 'https://c.saavncdn.com/artists/Yuvan_Shankar_Raja_004_20221010183017_500x500.jpg'},
  ];

  // Map of related artists
  final Map<String, List<Map<String, String>>> _relatedArtists = {
    'Arijit Singh': [
      {'name': 'Atif Aslam', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Atif_Aslam_500x500.jpg'},
      {'name': 'Jubin Nautiyal', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Jubin_Nautiyal_005_20230612140833_500x500.jpg'},
      {'name': 'Pritam', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Pritam_100_20230811120049_500x500.jpg'},
      {'name': 'Shreya Ghoshal', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Shreya_Ghoshal_004_20230607172828_500x500.jpg'},
      {'name': 'Amit Trivedi', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Amit_Trivedi_004_20230612140810_500x500.jpg'},
    ],
    'Pritam': [
      {'name': 'Arijit Singh', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Arijit_Singh_007_20230711171807_500x500.jpg'},
      {'name': 'Amit Trivedi', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Amit_Trivedi_004_20230612140810_500x500.jpg'},
      {'name': 'Vishal-Shekhar', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Vishal_Shekhar_004_20201015112108_500x500.jpg'},
      {'name': 'Sachin-Jigar', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Sachin_Jigar_004_20230614184650_500x500.jpg'},
    ],
    'A.R. Rahman': [
      {'name': 'Sid Sriram', 'lang': 'Tamil', 'image': 'https://c.saavncdn.com/artists/Sid_Sriram_007_20230623145455_500x500.jpg'},
      {'name': 'Shreya Ghoshal', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Shreya_Ghoshal_004_20230607172828_500x500.jpg'},
      {'name': 'Mohit Chauhan', 'lang': 'Hindi', 'image': 'https://c.saavncdn.com/artists/Mohit_Chauhan_004_20230612140733_500x500.jpg'},
      {'name': 'Haricharan', 'lang': 'Tamil', 'image': 'https://c.saavncdn.com/artists/Haricharan_500x500.jpg'},
    ],
    'Taylor Swift': [
      {'name': 'Olivia Rodrigo', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Olivia_Rodrigo_005_20220614134444_500x500.jpg'},
      {'name': 'Billie Eilish', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Billie_Eilish_005_20230303173752_500x500.jpg'},
      {'name': 'Sabrina Carpenter', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Sabrina_Carpenter_500x500.jpg'},
      {'name': 'Selena Gomez', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Selena_Gomez_500x500.jpg'},
    ],
    'Ed Sheeran': [
      {'name': 'Shawn Mendes', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Shawn_Mendes_500x500.jpg'},
      {'name': 'Justin Bieber', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Justin_Biber_500x500.jpg'},
      {'name': 'Lewis Capaldi', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Lewis_Capaldi_500x500.jpg'},
      {'name': 'Coldplay', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Coldplay_500x500.jpg'},
    ],
    'The Weeknd': [
      {'name': 'Drake', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Drake_500x500.jpg'},
      {'name': 'Post Malone', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Post_Malone_500x500.jpg'},
      {'name': 'Travis Scott', 'lang': 'English', 'image': 'https://c.saavncdn.com/artists/Travis_Scott_500x500.jpg'},
    ],
    'Diljit Dosanjh': [
      {'name': 'Guru Randhawa', 'lang': 'Punjabi', 'image': 'https://c.saavncdn.com/artists/Guru_Randhawa_007_20230713170327_500x500.jpg'},
      {'name': 'Amrinder Gill', 'lang': 'Punjabi', 'image': 'https://c.saavncdn.com/artists/Amrinder_Gill_500x500.jpg'},
      {'name': 'Karan Aujla', 'lang': 'Punjabi', 'image': 'https://c.saavncdn.com/artists/Karan_Aujla_007_20230713170701_500x500.jpg'},
    ],
    'Sidhu Moose Wala': [
      {'name': 'Karan Aujla', 'lang': 'Punjabi', 'image': 'https://c.saavncdn.com/artists/Karan_Aujla_007_20230713170701_500x500.jpg'},
      {'name': 'Amrit Maan', 'lang': 'Punjabi', 'image': 'https://c.saavncdn.com/artists/Amrit_Maan_500x500.jpg'},
      {'name': 'Prem Dhillon', 'lang': 'Punjabi', 'image': 'https://c.saavncdn.com/artists/Prem_Dhillon_500x500.jpg'},
    ],
  };

  // Dynamically constructed display list
  List<Map<String, String>> _displayArtists = [];

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    final query = _searchCtrl.text.toLowerCase().trim();
    
    // Filter base list by language and query
    var filtered = _artists.where((a) {
      final matchesLang = _selectedLanguage == 'All' || a['lang'] == _selectedLanguage;
      final matchesQuery = query.isEmpty || a['name']!.toLowerCase().contains(query);
      return matchesLang && matchesQuery;
    }).toList();

    // Dynamically insert related artists if their parent is selected
    final List<Map<String, String>> relatedToInsert = [];
    for (final selected in _selectedArtists) {
      if (_relatedArtists.containsKey(selected)) {
        for (final related in _relatedArtists[selected]!) {
          // Avoid duplicates
          final alreadyInBase = _artists.any((a) => a['name'] == related['name']);
          final alreadyInRelated = relatedToInsert.any((a) => a['name'] == related['name']);
          if (!alreadyInBase && !alreadyInRelated) {
            final matchesLang = _selectedLanguage == 'All' || related['lang'] == _selectedLanguage;
            final matchesQuery = query.isEmpty || related['name']!.toLowerCase().contains(query);
            if (matchesLang && matchesQuery) {
              relatedToInsert.add(related);
            }
          }
        }
      }
    }

    setState(() {
      _displayArtists = [...filtered, ...relatedToInsert];
    });
  }

  Future<void> _savePreferences() async {
    if (_selectedArtists.length < 3) return;
    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseService.instance.saveFavoriteArtists(_selectedArtists.toList());
      widget.onCompleted();
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: mq.size.width > 500 ? 460 : mq.size.width * 0.9,
          height: mq.size.height * 0.78,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0C16).withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Your Vibe',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select at least 3 favorite artists to personalize your suggestions.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Search Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => _refreshList(),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search artist...',
                      hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.35), fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Language Selector
              SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final lang = _languages[i];
                    final active = _selectedLanguage == lang;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedLanguage = lang;
                        });
                        _refreshList();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? AppColors.accent : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active ? AppColors.accent : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Text(
                          lang,
                          style: GoogleFonts.inter(
                            color: active ? Colors.white : Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Artist Grid
              Expanded(
                child: _displayArtists.isEmpty
                    ? Center(
                        child: Text(
                          'No artists found.',
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4)),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.8,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                        itemCount: _displayArtists.length,
                        itemBuilder: (context, i) {
                          final a = _displayArtists[i];
                          final name = a['name']!;
                          final image = a['image']!;
                          final isSelected = _selectedArtists.contains(name);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedArtists.remove(name);
                                } else {
                                  _selectedArtists.add(name);
                                }
                              });
                              _refreshList();
                            },
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 76,
                                      height: 76,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? AppColors.accent : Colors.white.withOpacity(0.08),
                                          width: isSelected ? 3 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.accent.withOpacity(0.4),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(38),
                                        child: Image.network(
                                          image,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: Colors.white.withOpacity(0.05),
                                            child: Icon(Icons.person, color: Colors.white.withOpacity(0.3)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: AppColors.accent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedArtists.length} Selected',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: (_selectedArtists.length >= 3 && !_isSaving) ? _savePreferences : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        disabledBackgroundColor: Colors.white.withOpacity(0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Continue',
                              style: GoogleFonts.inter(
                                color: _selectedArtists.length >= 3 ? Colors.white : Colors.white.withOpacity(0.35),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
