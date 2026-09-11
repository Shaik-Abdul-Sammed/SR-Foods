import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  String _customerName = 'Customer';
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    final name = await _storage.read(key: 'owner_name');
    if (name != null && mounted) {
      setState(() {
        _customerName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickStats().animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0),
                  const Gap(32),
                  _buildSectionTitle('Featured Products').animate().fade(delay: 300.ms).slideX(begin: -0.1, end: 0),
                  const Gap(16),
                  _buildFeaturedProducts().animate().fade(delay: 400.ms).slideX(begin: 0.1, end: 0),
                  const Gap(32),
                  _buildSectionTitle('Recent Orders').animate().fade(delay: 500.ms).slideX(begin: -0.1, end: 0),
                  const Gap(16),
                  _buildRecentOrders().animate().fade(delay: 600.ms).slideY(begin: 0.1, end: 0),
                  const Gap(40),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Future: Navigate to Create Order
          context.push(AppRoutes.products);
        },
        backgroundColor: const Color(0xFF3B82F6), // Blue 500
        icon: const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white),
        label: Text('New Order', style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 800.ms, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
              ),
            ),
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0, top: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Welcome back,',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                    ).animate().fade().slideX(begin: -0.2, end: 0),
                    const Gap(4),
                    Text(
                      _customerName,
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ).animate().fade(delay: 100.ms).slideX(begin: -0.2, end: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
          onPressed: () {},
        ).animate().scale(delay: 200.ms),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () async {
            await _storage.deleteAll();
            if (mounted) context.go(AppRoutes.welcome);
          },
        ).animate().scale(delay: 300.ms),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Active Orders',
            value: '2',
            icon: Icons.local_shipping_rounded,
            color: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFEF3C7),
          ),
        ),
        const Gap(16),
        Expanded(
          child: _StatCard(
            title: 'Loyalty Points',
            value: '450',
            icon: Icons.stars_rounded,
            color: const Color(0xFF8B5CF6),
            bgColor: const Color(0xFFEDE9FE),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleLarge.copyWith(
        color: const Color(0xFF0F172A),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildFeaturedProducts() {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const Gap(16),
        itemBuilder: (context, index) {
          final List<Map<String, dynamic>> products = [
            {'name': 'Premium Rice 25kg', 'price': '₹1,250', 'icon': Icons.rice_bowl},
            {'name': 'Atta 10kg', 'price': '₹450', 'icon': Icons.shopping_bag},
            {'name': 'Refined Oil 5L', 'price': '₹850', 'icon': Icons.water_drop},
          ];
          return Container(
            width: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(products[index]['icon'] as IconData, color: const Color(0xFF3B82F6), size: 32),
                ),
                const Gap(16),
                Text(
                  products[index]['name'] as String,
                  style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const Gap(4),
                Text(
                  products[index]['price'] as String,
                  style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentOrders() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 2,
      separatorBuilder: (context, index) => const Gap(12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF64748B)),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${1024 + index}',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Gap(4),
                    Text(
                      DateTime.now().subtract(Duration(days: index * 2)).toString().substring(0, 10),
                      style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: index == 0 ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  index == 0 ? 'Delivered' : 'Processing',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: index == 0 ? const Color(0xFF15803D) : const Color(0xFF0369A1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Gap(16),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(4),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
