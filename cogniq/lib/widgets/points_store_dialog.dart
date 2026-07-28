import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/settings_manager.dart';
import '../utils/point_manager.dart';
import '../utils/purchase_manager.dart';
import '../utils/iap_catalog.dart';

class PointsStoreDialog extends StatefulWidget {
  final VoidCallback? onPurchaseComplete;

  const PointsStoreDialog({
    super.key,
    this.onPurchaseComplete,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onPurchaseComplete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: PointsStoreDialog(
          onPurchaseComplete: onPurchaseComplete,
        ),
      ),
    );
  }

  @override
  State<PointsStoreDialog> createState() => _PointsStoreDialogState();
}

class _PointsStoreDialogState extends State<PointsStoreDialog> {
  int _pointBalance = 0;
  bool _purchaseInFlight = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final balance = await PointManager.getPoints();
    if (mounted) {
      setState(() {
        _pointBalance = balance;
      });
    }
  }

  Future<void> _buyProduct(IapProduct product) async {
    setState(() {
      _purchaseInFlight = true;
    });

    try {
      await PurchaseManager.buy(
        product,
        onStoreUnavailable: () {
          _showSnackBar('Store is currently unavailable.', Colors.redAccent);
          if (mounted) {
            setState(() {
              _purchaseInFlight = false;
            });
          }
        },
        onProductNotFound: () {
          _showSnackBar('Product not found in the store.', Colors.redAccent);
          if (mounted) {
            setState(() {
              _purchaseInFlight = false;
            });
          }
        },
      );
      
      // Wait briefly for native stream listener confirmation
      await Future.delayed(const Duration(seconds: 2));
      await _loadBalance();
      if (widget.onPurchaseComplete != null) {
        widget.onPurchaseComplete!();
      }
    } catch (e) {
      _showSnackBar('An error occurred during checkout.', Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() {
          _purchaseInFlight = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showBundle = !settingsNotifier.adsRemoved;

    return Container(
      decoration: BoxDecoration(
        color: context.bgDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textMuted.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header & Point Balance HUD
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Points Store',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.warmAmber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.warmAmber.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology, color: AppTheme.warmAmber, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '$_pointBalance IQ',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warmAmber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Spend IQ Points on hints across all games. No subscriptions.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            if (_purchaseInFlight)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 30.0),
                  child: CircularProgressIndicator(color: AppTheme.dustyMauve),
                ),
              )
            else ...[
              // Starter Bundle (Promo Container)
              if (showBundle) ...[
                _buildStarterBundleCard(),
                const SizedBox(height: 16),
              ],

              // Consumable Point Packs List
              Text(
                'IQ Point Packs',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildProductRow(IapCatalog.points500, '500 IQ Points'),
                    const SizedBox(height: 10),
                    _buildProductRow(IapCatalog.points1200, '1,200 IQ Points'),
                    const SizedBox(height: 10),
                    _buildProductRow(IapCatalog.points3000, '3,000 IQ Points'),
                    const SizedBox(height: 10),
                    _buildProductRow(IapCatalog.points7000, '7,000 IQ Points'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStarterBundleCard() {
    final details = PurchaseManager.detailsFor(IapCatalog.bundle.id);
    final price = details?.price ?? 'Rs 149';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3F2B96), Color(0xFFA8C0F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'STARTER DEAL',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Starter Bundle Pack',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Remove ads permanently + get 1,500 IQ Points for hints!',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _buyProduct(IapCatalog.bundle),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF3F2B96),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              price,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(IapProduct product, String title) {
    final details = PurchaseManager.detailsFor(product.id);
    final price = details?.price ?? (product.id == 'points_500' ? 'Rs 29' : product.id == 'points_1200' ? 'Rs 59' : product.id == 'points_3000' ? 'Rs 149' : 'Rs 299');

    return Container(
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: product.bestValue ? Colors.cyan.withOpacity(0.5) : context.textMuted.withOpacity(0.1),
          width: product.bestValue ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.warmAmber.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology, color: AppTheme.warmAmber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                if (product.bestValue) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'BEST VALUE',
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Colors.cyan,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _buyProduct(product),
            style: ElevatedButton.styleFrom(
              backgroundColor: product.bestValue ? Colors.cyan : context.textMuted.withOpacity(0.15),
              foregroundColor: product.bestValue ? Colors.white : context.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              price,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
