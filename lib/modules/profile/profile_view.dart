import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/models/user_profile.dart';
import '../../state/dashboard_provider.dart';
import '../../state/host_provider.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isMediumScreen = screenSize.width >= 600 && screenSize.width < 1200;
    final isLargeScreen = screenSize.width >= 1200;

    // Adjust padding and sizes based on screen size
    final horizontalPadding = isSmallScreen
        ? 16.0
        : isMediumScreen
        ? 24.0
        : 32.0;
    final verticalPadding = isSmallScreen ? 16.0 : 24.0;
    final fontSizeTitle = isSmallScreen ? 20.0 : 24.0;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profileAsync = ref.watch(profileDataProvider);
    final isLoading = profileAsync.isLoading;
    final error = profileAsync.maybeWhen(error: (error, _) => error.toString(), orElse: () => null);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(fontSize: fontSizeTitle)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () async {
              try {
                await ref.read(authRepositoryProvider).logout();
                await ref.read(hostProvider.notifier).clearSelection();
                // Clear auth storage to prevent session restoration with wrong department
                await ref.read(authStorageProvider).clearAll();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
                }
              }
            },
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cs.primary.withOpacity(0.8), cs.primaryContainer.withOpacity(0.6), cs.surface],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const _LoadingView()
              : error != null
              ? _ErrorView(
                  error: error,
                  onRetry: () => ref.read(profileDataProvider.notifier).refreshProfileData(),
                )
              : profileAsync.maybeWhen(
                  data: (Object? profile) => profile != null
                      ? _ProfileContent(
                          profile: profile as UserProfile,
                          horizontalPadding: horizontalPadding,
                          verticalPadding: verticalPadding,
                        )
                      : const _NoProfileView(),
                  orElse: () => const _NoProfileView(),
                ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
          SizedBox(height: 16),
          Text('Loading profile...', style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: cs.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load profile',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoProfileView extends StatelessWidget {
  const _NoProfileView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off, size: 64, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  'No profile data available',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please log in to view your profile',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile, required double verticalPadding, required double horizontalPadding});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header Card
          _ProfileHeaderCard(profile: profile),
          const SizedBox(height: 24),

          // Quick Stats
          _QuickStatsSection(profile: profile),
          const SizedBox(height: 24),

          // Personal Information
          _SectionCard(
            title: 'Personal Information',
            icon: Icons.person,
            color: Colors.blue,
            child: _PersonalInfoSection(profile: profile),
          ),
          const SizedBox(height: 16),

          // Contact Information
          _SectionCard(
            title: 'Contact Information',
            icon: Icons.contact_phone,
            color: Colors.green,
            child: _ContactInfoSection(profile: profile),
          ),
          const SizedBox(height: 16),

          // Employment Information
          _SectionCard(
            title: 'Employment Information',
            icon: Icons.work,
            color: Colors.purple,
            child: _EmploymentInfoSection(profile: profile),
          ),
          const SizedBox(height: 16),

          // Government IDs
          _SectionCard(
            title: 'Government IDs',
            icon: Icons.badge,
            color: Colors.orange,
            child: _GovernmentIdsSection(profile: profile),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ProfileHeaderCard extends ConsumerWidget {
  const _ProfileHeaderCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedDepartment = ref.watch(hostProvider);

    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primaryContainer, cs.primaryContainer.withOpacity(0.8)],
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile Image with Border
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.primary, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: cs.surface,
                backgroundImage: profile.userImage != null
                    ? NetworkImage(
                        '${selectedDepartment?.baseUrl ?? "http://192.168.0.143:8091"}${profile.userImage}',
                      )
                    : null,
                child: profile.userImage == null
                    ? Icon(Icons.person, size: 50, color: cs.onSurfaceVariant)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            // Name and Title
            Text(
              '${profile.userFname} ${profile.userMname ?? ''} ${profile.userLname}'.trim(),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              profile.userPosition ?? 'No position specified',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              profile.userEmail,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onPrimaryContainer.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Role Badge
            if (profile.role != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  profile.role!.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            // Admin Badge
            if (profile.isAdmin == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings, size: 16, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      'ADMIN',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickStatsSection extends StatelessWidget {
  const _QuickStatsSection({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Employee ID',
            value: profile.userId.toString(),
            icon: Icons.badge,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'RF ID',
            value: profile.rfId ?? 'N/A',
            icon: Icons.nfc,
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(padding: const EdgeInsets.all(16.0), child: child),
        ],
      ),
    );
  }
}

class _PersonalInfoSection extends StatelessWidget {
  const _PersonalInfoSection({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoTile(
          icon: Icons.person,
          label: 'Full Name',
          value: '${profile.userFname} ${profile.userMname ?? ''} ${profile.userLname}'.trim(),
        ),
        _InfoTile(
          icon: Icons.calendar_today,
          label: 'Date of Hire',
          value: profile.userDateOfHire ?? 'Not specified',
        ),
        if (profile.updateAt != null)
          _InfoTile(
            icon: Icons.update,
            label: 'Last Updated',
            value: profile.updateAt!.toLocal().toString().split(' ')[0],
          ),
      ],
    );
  }
}

class _ContactInfoSection extends StatelessWidget {
  const _ContactInfoSection({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoTile(icon: Icons.email, label: 'Email Address', value: profile.userEmail),
        _InfoTile(
          icon: Icons.phone,
          label: 'Contact Number',
          value: profile.userContact ?? 'Not specified',
        ),
        _InfoTile(icon: Icons.location_on, label: 'Address', value: _formatAddress(profile)),
      ],
    );
  }

  String _formatAddress(UserProfile profile) {
    final parts = [profile.userBrgy, profile.userCity, profile.userProvince]
        .where(
          (part) =>
              part != null &&
              part.isNotEmpty &&
              part != 'Select a Barangay' &&
              part != 'Select a City / Municipality',
        )
        .toList();

    return parts.isNotEmpty ? parts.join(', ') : 'Not specified';
  }
}

class _EmploymentInfoSection extends StatelessWidget {
  const _EmploymentInfoSection({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoTile(
          icon: Icons.work,
          label: 'Position',
          value: profile.userPosition ?? 'Not specified',
        ),
        _InfoTile(
          icon: Icons.business,
          label: 'Department',
          value: profile.userDepartment?.toString() ?? 'Not specified',
        ),
        _InfoTile(icon: Icons.nfc, label: 'RF ID', value: profile.rfId ?? 'Not specified'),
        if (profile.isAdmin != null)
          _InfoTile(
            icon: Icons.admin_panel_settings,
            label: 'Admin Status',
            value: profile.isAdmin! ? 'Administrator' : 'Regular User',
          ),
      ],
    );
  }
}

class _GovernmentIdsSection extends StatelessWidget {
  const _GovernmentIdsSection({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoTile(
          icon: Icons.account_balance,
          label: 'SSS Number',
          value: profile.userSss ?? 'Not specified',
        ),
        _InfoTile(
          icon: Icons.local_hospital,
          label: 'PhilHealth Number',
          value: profile.userPhilhealth ?? 'Not specified',
        ),
        _InfoTile(
          icon: Icons.account_balance_wallet,
          label: 'Pag-IBIG Number',
          value: profile.userPagibig ?? 'Not specified',
        ),
        _InfoTile(icon: Icons.receipt, label: 'TIN', value: profile.userTin ?? 'Not specified'),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
