import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';
import '../../providers/booking_provider.dart';

class RatingsReviewsScreen extends StatefulWidget {
  const RatingsReviewsScreen({super.key});

  @override
  State<RatingsReviewsScreen> createState() => _RatingsReviewsScreenState();
}

class _RatingsReviewsScreenState extends State<RatingsReviewsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<BookingProvider>().fetchRatings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = RatingsReviewsStrings(isThai: isThai);
    final provider = context.watch<BookingProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 60, 24, 30),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PGuard',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        strings.appBarTitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildOverallRating(strings, provider.ratings),
                        const SizedBox(height: 20),
                        _buildRatingBreakdown(strings, provider.ratings),
                        const SizedBox(height: 20),
                        _buildRecentReviews(strings, provider.ratings),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallRating(RatingsReviewsStrings strings, Map<String, dynamic>? ratings) {
    final overall = (ratings?['overall_rating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = (ratings?['total_reviews'] as num?)?.toInt() ?? 0;
    final fullStars = overall.floor();
    final hasHalf = (overall - fullStars) >= 0.3;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppGradients.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            strings.overallRating,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            totalReviews > 0 ? overall.toStringAsFixed(1) : '-',
            style: GoogleFonts.inter(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              if (i < fullStars) {
                return const Icon(Icons.star_rounded, color: Colors.amber, size: 28);
              } else if (i == fullStars && hasHalf) {
                return const Icon(Icons.star_half_rounded, color: Colors.amber, size: 28);
              }
              return Icon(Icons.star_outline_rounded, color: Colors.amber.withValues(alpha: 0.4), size: 28);
            }),
          ),
          const SizedBox(height: 8),
          Text(
            totalReviews > 0
                ? (LanguageProvider.of(context).isThai
                    ? 'จาก $totalReviews รีวิว'
                    : 'Based on $totalReviews reviews')
                : (LanguageProvider.of(context).isThai ? 'ยังไม่มีรีวิว' : 'No reviews yet'),
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBreakdown(RatingsReviewsStrings strings, Map<String, dynamic>? ratings) {
    final punctuality = (ratings?['avg_punctuality'] as num?)?.toDouble();
    final professionalism = (ratings?['avg_professionalism'] as num?)?.toDouble();
    final communication = (ratings?['avg_communication'] as num?)?.toDouble();
    final appearance = (ratings?['avg_appearance'] as num?)?.toDouble();

    final categories = <Map<String, dynamic>>[
      if (punctuality != null) {'label': strings.punctuality, 'rating': punctuality},
      if (professionalism != null) {'label': strings.professionalism, 'rating': professionalism},
      if (communication != null) {'label': strings.communication, 'rating': communication},
      if (appearance != null) {'label': strings.appearance, 'rating': appearance},
    ];

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.ratingBreakdown,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          ...categories.map((cat) => _buildRatingBar(
                cat['label'] as String,
                cat['rating'] as double,
              )),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String label, double rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rating / 5.0,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReviews(RatingsReviewsStrings strings, Map<String, dynamic>? ratings) {
    final reviews = (ratings?['recent_reviews'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.recentReviews,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
        if (reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 48,
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LanguageProvider.of(context).isThai ? 'ยังไม่มีรีวิว' : 'No reviews yet',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ...reviews.map((review) {
            final r = review as Map<String, dynamic>;
            final createdAt = r['created_at'] as String? ?? '';
            final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
            return _buildReviewCard(
              r['customer_name'] as String? ?? '-',
              r['review_text'] as String? ?? '',
              dateStr,
              (r['overall_rating'] as num?)?.toDouble() ?? 0.0,
            );
          }),
      ],
    );
  }

  Widget _buildReviewCard(String name, String text, String date, double rating) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: AppColors.info, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    Text(
                      date,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              text,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
