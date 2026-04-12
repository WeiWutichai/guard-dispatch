import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';

class GuardDetailScreen extends StatefulWidget {
  final Map<String, dynamic> guard;
  final VoidCallback onConfirm;

  const GuardDetailScreen({
    super.key,
    required this.guard,
    required this.onConfirm,
  });

  @override
  State<GuardDetailScreen> createState() => _GuardDetailScreenState();
}

class _GuardDetailScreenState extends State<GuardDetailScreen> {
  @override
  void initState() {
    super.initState();
    final guardId = widget.guard['id'] as String? ?? '';
    if (guardId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<BookingProvider>().fetchGuardDetail(guardId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final guard = widget.guard;
    final name = guard['full_name'] as String? ?? '-';
    final distanceKm = (guard['distance_km'] as num?)?.toDouble() ?? 0;
    final experienceYears = guard['experience_years'] as int? ?? 0;
    final completedJobs = (guard['completed_jobs'] as num?)?.toInt() ?? 0;
    final rating = (guard['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (guard['review_count'] as num?)?.toInt() ?? 0;
    final lastSeenAt = guard['last_seen_at'] as String?;

    int minutesAgo = 0;
    if (lastSeenAt != null) {
      final dt = DateTime.tryParse(lastSeenAt);
      if (dt != null) {
        minutesAgo = DateTime.now().toUtc().difference(dt).inMinutes;
      }
    }
    final isOnlineNow = minutesAgo <= 5;

    // Badge
    String badgeText;
    Color badgeBg;
    Color badgeTextColor;
    IconData badgeIcon;
    if (completedJobs >= 50) {
      badgeText = isThai ? 'เจ้าหน้าที่ยอดนิยม' : 'Top Guard';
      badgeBg = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFB45309);
      badgeIcon = Icons.star_rounded;
    } else if (completedJobs >= 20) {
      badgeText = isThai ? 'มีประสบการณ์' : 'Experienced';
      badgeBg = const Color(0xFFDBEAFE);
      badgeTextColor = const Color(0xFF1D4ED8);
      badgeIcon = Icons.verified_rounded;
    } else {
      badgeText = isThai ? 'ว่าง' : 'Available';
      badgeBg = const Color(0xFFF0FDF4);
      badgeTextColor = AppColors.primary;
      badgeIcon = Icons.check_circle_outline_rounded;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Green header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 60, 24, 20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  isThai ? 'รายละเอียดเจ้าหน้าที่' : 'Guard Details',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Avatar
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isOnlineNow ? AppColors.primary : AppColors.border,
                                  width: 2.5,
                                ),
                              ),
                              child: guard['avatar_url'] != null
                                  ? ClipOval(
                                      child: Image.network(
                                        guard['avatar_url'],
                                        fit: BoxFit.cover,
                                        width: 72,
                                        height: 72,
                                        errorBuilder: (_, _, _) => const Icon(
                                            Icons.person_rounded,
                                            size: 36,
                                            color: AppColors.primary),
                                      ),
                                    )
                                  : const Icon(Icons.person_rounded,
                                      size: 36, color: AppColors.primary),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      // Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: badgeBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(badgeIcon, size: 12, color: badgeTextColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              badgeText,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: badgeTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Online status
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isOnlineNow
                                                  ? AppColors.primary
                                                  : AppColors.disabled,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isOnlineNow
                                                ? (isThai ? 'ออนไลน์' : 'Online')
                                                : '${minutesAgo}m',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isOnlineNow
                                                  ? AppColors.primary
                                                  : AppColors.disabled,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Distance
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.near_me_rounded,
                                      size: 13, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${distanceKm.toStringAsFixed(1)} ${isThai ? "กม." : "km"}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Profile info from API (gender, previous workplace)
                        Consumer<BookingProvider>(
                          builder: (context, provider, _) {
                            final profile = provider.guardProfile;
                            if (profile == null) return const SizedBox.shrink();

                            final gender = profile['gender'] as String?;
                            final workplace = profile['previous_workplace'] as String?;

                            if (gender == null && workplace == null) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  if (gender != null) ...[
                                    Icon(Icons.person_outline_rounded,
                                        size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      gender,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (gender != null && workplace != null)
                                    const SizedBox(width: 16),
                                  if (workplace != null) ...[
                                    Icon(Icons.business_rounded,
                                        size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        workplace,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),
                        // Stats row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStat(
                                Icons.star_rounded,
                                const Color(0xFFF59E0B),
                                rating.toStringAsFixed(1),
                                '$reviewCount ${isThai ? "รีวิว" : "reviews"}',
                              ),
                              Container(
                                  width: 1,
                                  height: 32,
                                  color: AppColors.border),
                              _buildStat(
                                Icons.check_circle_rounded,
                                AppColors.primary,
                                '$completedJobs',
                                isThai ? 'งานสำเร็จ' : 'completed',
                              ),
                              Container(
                                  width: 1,
                                  height: 32,
                                  color: AppColors.border),
                              _buildStat(
                                Icons.work_history_rounded,
                                const Color(0xFF6366F1),
                                '$experienceYears ${isThai ? "ปี" : "yr"}',
                                isThai ? 'ประสบการณ์' : 'experience',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Documents, category ratings + reviews from API
                  Consumer<BookingProvider>(
                    builder: (context, provider, _) {
                      if (provider.isLoadingReviews && provider.isLoadingProfile) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final reviews = provider.guardReviews;
                      final profile = provider.guardProfile;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Documents section
                          if (profile != null) _buildDocumentsSection(profile, isThai),

                          // Category ratings
                          if (reviews != null) _buildCategoryRatings(reviews, isThai),

                          // Reviews list
                          _buildReviewsList(reviews, isThai),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom confirm button
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isThai ? 'ยืนยันการจอง' : 'Confirm Booking',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(Map<String, dynamic> profile, bool isThai) {
    final docs = <MapEntry<String, String>>[];

    final docFields = [
      MapEntry('id_card_url', isThai ? 'บัตรประชาชน' : 'ID Card'),
      MapEntry('security_license_url', isThai ? 'ใบอนุญาต รปภ.' : 'Security License'),
      MapEntry('training_cert_url', isThai ? 'ใบประกาศนียบัตร' : 'Training Certificate'),
      MapEntry('criminal_check_url', isThai ? 'ตรวจประวัติอาชญากรรม' : 'Criminal Check'),
      MapEntry('driver_license_url', isThai ? 'ใบขับขี่' : 'Driver\'s License'),
    ];

    for (final field in docFields) {
      final url = profile[field.key] as String?;
      if (url != null && url.isNotEmpty) {
        docs.add(MapEntry(field.value, url));
      }
    }

    if (docs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isThai ? 'เอกสารที่ยืนยัน' : 'Verified Documents',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return GestureDetector(
                onTap: () => _showDocumentViewer(context, doc.value, doc.key),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.network(
                          doc.value,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(
                              Icons.description_outlined,
                              color: AppColors.textSecondary,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 100,
                      child: Text(
                        doc.key,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _showDocumentViewer(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRatings(Map<String, dynamic> reviews, bool isThai) {
    final punctuality = (reviews['punctuality'] as num?)?.toDouble();
    final professionalism = (reviews['professionalism'] as num?)?.toDouble();
    final communication = (reviews['communication'] as num?)?.toDouble();
    final appearance = (reviews['appearance'] as num?)?.toDouble();

    final categories = <MapEntry<String, double?>>[];
    categories.add(MapEntry(isThai ? 'ตรงเวลา' : 'Punctuality', punctuality));
    categories.add(MapEntry(isThai ? 'ความเป็นมืออาชีพ' : 'Professionalism', professionalism));
    categories.add(MapEntry(isThai ? 'การสื่อสาร' : 'Communication', communication));
    categories.add(MapEntry(isThai ? 'บุคลิกภาพ' : 'Appearance', appearance));

    final hasAny = categories.any((e) => e.value != null);
    if (!hasAny) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isThai ? 'คะแนนรายหมวด' : 'Category Ratings',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: categories
                .where((e) => e.value != null)
                .map((e) => _buildRatingBar(e.key, e.value!))
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRatingBar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 5.0,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  value >= 4.0
                      ? AppColors.primary
                      : value >= 3.0
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value.toStringAsFixed(1),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList(Map<String, dynamic>? reviews, bool isThai) {
    final recentReviews =
        (reviews?['recent_reviews'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final totalReviews = (reviews?['total_reviews'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isThai ? 'รีวิวจากลูกค้า' : 'Customer Reviews',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$totalReviews',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (recentReviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 40,
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  isThai ? 'ยังไม่มีรีวิว' : 'No reviews yet',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...recentReviews.map((review) => _buildReviewCard(review, isThai)),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, bool isThai) {
    final customerName = review['customer_name'] as String? ?? '-';
    final overallRating = (review['overall_rating'] as num?)?.toDouble() ?? 0;
    final reviewText = review['review_text'] as String?;
    final createdAt = review['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Customer initial
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatRelativeTime(createdAt, isThai),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final starValue = i + 1;
                  return Icon(
                    starValue <= overallRating
                        ? Icons.star_rounded
                        : (starValue - 0.5 <= overallRating
                            ? Icons.star_half_rounded
                            : Icons.star_outline_rounded),
                    size: 16,
                    color: const Color(0xFFF59E0B),
                  );
                }),
              ),
            ],
          ),
          if (reviewText != null && reviewText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              reviewText,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRelativeTime(String? isoString, bool isThai) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now().toUtc();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return isThai ? 'เมื่อสักครู่' : 'Just now';
      if (diff.inMinutes < 60) {
        return isThai
            ? '${diff.inMinutes} นาทีที่แล้ว'
            : '${diff.inMinutes}m ago';
      }
      if (diff.inHours < 24) {
        return isThai
            ? '${diff.inHours} ชั่วโมงที่แล้ว'
            : '${diff.inHours}h ago';
      }
      if (diff.inDays < 7) {
        return isThai
            ? '${diff.inDays} วันที่แล้ว'
            : '${diff.inDays}d ago';
      }
      if (diff.inDays < 30) {
        final weeks = diff.inDays ~/ 7;
        return isThai
            ? '$weeks สัปดาห์ที่แล้ว'
            : '${weeks}w ago';
      }
      final months = diff.inDays ~/ 30;
      return isThai
          ? '$months เดือนที่แล้ว'
          : '${months}mo ago';
    } catch (_) {
      return '';
    }
  }

  Widget _buildStat(
      IconData icon, Color iconColor, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
