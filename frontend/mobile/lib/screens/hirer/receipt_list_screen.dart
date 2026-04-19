import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';
import '../../theme/colors.dart';
import 'receipt_detail_screen.dart';

/// List of past completed-job receipts for the current hirer/customer.
/// Entry point from HirerProfileScreen menu. Tapping a row opens
/// ReceiptDetailScreen where the user can view or download the PDF.
class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BookingProvider>().fetchReceipts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final s = ReceiptsStrings(isThai: isThai);
    final provider = context.watch<BookingProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          _header(context, s),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => provider.fetchReceipts(),
              child: _body(provider, s, isThai),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, ReceiptsStrings s) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 60, 24, 30),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'P-Guard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  s.listTitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BookingProvider provider, ReceiptsStrings s, bool isThai) {
    if (provider.isLoadingReceipts && provider.receipts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (provider.error != null && provider.receipts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline_rounded,
              size: 64, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Center(
            child: Text(
              s.loadError,
              style: const TextStyle(fontSize: 16, color: Colors.redAccent),
            ),
          ),
        ],
      );
    }

    if (provider.receipts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.receipt_long_outlined,
              size: 64, color: Color(0xFFBDBDBD)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              s.empty,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3A3A3C),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              s.emptySubtitle,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      itemCount: provider.receipts.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ReceiptCard(
            receipt: provider.receipts[index],
            isThai: isThai,
          ),
        );
      },
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt, required this.isThai});

  final Map<String, dynamic> receipt;
  final bool isThai;

  @override
  Widget build(BuildContext context) {
    final receiptNo = (receipt['receipt_no'] ?? '-').toString();
    final guard = (receipt['guard_name'] ?? '-').toString();
    final address = (receipt['service_address'] ?? '-').toString();
    final net = _num(receipt['net_amount']) ?? 0;
    final paidAt = _date(receipt['paid_at']) ?? _date(receipt['completed_at']);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptDetailScreen(receipt: receipt),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receiptNo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      guard,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6B70),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '฿${NumberFormat("#,##0.00").format(net)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (paidAt != null)
                    Text(
                      DateFormat('dd/MM/yyyy').format(paidAt.toLocal()),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  static DateTime? _date(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
