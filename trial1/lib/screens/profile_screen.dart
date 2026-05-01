import 'package:flutter/material.dart';
import 'package:trial1/models/user_profile.dart';
import 'package:trial1/screens/profile_setup_screen.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/widgets/skeleton_loader.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;

  const ProfileScreen({
    super.key,
    this.showBackButton = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
  }

  Future<UserProfile> _fetchProfile() async {
    final data = await BackendService.fetchUserProfile();
    return UserProfile.fromJson(data);
  }

  int _calculateSemester(int admissionYear) {
    if (admissionYear <= 0) {
      return 1;
    }

    final now = DateTime.now();
    final academicYearStart = now.month >= 8 ? now.year : now.year - 1;
    final yearsSinceAdmission = academicYearStart - admissionYear;
    final semester = yearsSinceAdmission * 2 + (now.month >= 8 ? 1 : 2);
    return semester.clamp(1, 8);
  }

  int _calculateYearFromSemester(int semester) {
    return ((semester + 1) ~/ 2).clamp(1, 4);
  }

  String _yearLabel(int year) {
    return switch (year) {
      1 => '1st Year',
      2 => '2nd Year',
      3 => '3rd Year',
      _ => '${year}th Year',
    };
  }

  double _horizontalPadding(double width) {
    if (width < 600) {
      return 16;
    } else if (width < 1200) {
      return 24;
    } else if (width < 1600) {
      return 32;
    }
    return 48;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: const Text('Profile'),
      ),
      body: LayoutBuilder(
        builder: (context, snapshot) {
          final isWide = snapshot.maxWidth >= 900;
          final horizontalPadding = _horizontalPadding(snapshot.maxWidth);

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            child: FutureBuilder<UserProfile>(
              future: _profileFuture,
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState != ConnectionState.done) {
                  return _buildProfileSkeleton(isWide: isWide);
                }

                if (profileSnapshot.hasError || !profileSnapshot.hasData) {
                  return const Center(child: Text('Failed to load profile'));
                }

                final profile = profileSnapshot.data!;
                final semester = _calculateSemester(profile.admissionYear);
                final year = _calculateYearFromSemester(semester);

                return _buildProfileContent(
                  profile: profile,
                  semester: semester,
                  year: year,
                  isWide: isWide,
                  theme: theme,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileContent({
    required UserProfile profile,
    required int semester,
    required int year,
    required bool isWide,
    required ThemeData theme,
  }) {
    final primaryColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileHeader(profile, theme),
        const SizedBox(height: 18),
        _buildIdentityCard(profile, semester, year, theme),
        const SizedBox(height: 16),
        _buildAcademicDetails(profile, semester, year, theme),
      ],
    );

    final sideColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile.oauthConnected) ...[
          _buildConnectedAccountsCard(profile, theme),
          const SizedBox(height: 16),
        ] else ...[
          _buildGmailActionCard(theme),
          const SizedBox(height: 16),
        ],
        _buildAccountActionsCard(theme),
      ],
    );

    return SingleChildScrollView(
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 65, child: primaryColumn),
                const SizedBox(width: 16),
                Expanded(flex: 35, child: sideColumn),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [primaryColumn, const SizedBox(height: 16), sideColumn],
            ),
    );
  }
Widget _buildGmailActionCard(ThemeData theme) {
  final accent = theme.colorScheme.primary;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    decoration: BoxDecoration(
      color: theme.colorScheme.surface, // 🔥 solid surface (not translucent)
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: theme.colorScheme.outline.withValues(alpha: 0.3), // 🔥 neutral border
        width: 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ICON (neutral, not accent-heavy)
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.mail_outline,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),

        const SizedBox(height: 16),

        // TITLE
        Text(
          'Connect Gmail',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 6),

        // DESCRIPTION
        Text(
          'Unlock your dashboard and automate your academic tracking.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),

        const SizedBox(height: 18),

        // BUTTON (clear CTA)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              try {
                await BackendService.startGoogleOAuth();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to start Gmail OAuth: $e'),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0, // 🔥 no material shadow
            ),
            child: const Text('Connect Gmail'),
          ),
        ),
      ],
    ),
  );
}
  Widget _buildProfileSkeleton({required bool isWide}) {
    final primaryColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            SkeletonLoader(
              width: 72,
              height: 72,
              borderRadius: BorderRadius.all(Radius.circular(36)),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 180, height: 24),
                  SizedBox(height: 10),
                  SkeletonLoader(width: 260, height: 14),
                ],
              ),
            ),
            SkeletonLoader(width: 84, height: 42),
          ],
        ),
        const SizedBox(height: 20),
        const SkeletonLoader(width: double.infinity, height: 126),
        const SizedBox(height: 18),
        const SkeletonLoader(width: 150, height: 20),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: isWide ? 2 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isWide ? 3.2 : 4.5,
          children: const [
            SkeletonLoader(width: double.infinity, height: double.infinity),
            SkeletonLoader(width: double.infinity, height: double.infinity),
            SkeletonLoader(width: double.infinity, height: double.infinity),
            SkeletonLoader(width: double.infinity, height: double.infinity),
          ],
        ),
      ],
    );

    final sideColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonLoader(width: double.infinity, height: 124),
        SizedBox(height: 16),
        SkeletonLoader(width: double.infinity, height: 230),
      ],
    );

    return SingleChildScrollView(
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 65, child: primaryColumn),
                const SizedBox(width: 16),
                Expanded(flex: 35, child: sideColumn),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [primaryColumn, const SizedBox(height: 16), sideColumn],
            ),
    );
  }

  void _openEditProfile(UserProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileFormScreen(
          mode: ProfileFormMode.edit,
          profile: profile,
          onProfileUpdated: () {
            setState(() {
              _profileFuture = _fetchProfile();
            });
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserProfile profile, ThemeData theme) {
    final accent = theme.colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: accent.withValues(alpha: 0.12),
          child: Text(
            profile.fullName.isNotEmpty
                ? profile.fullName[0].toUpperCase()
                : '?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.fullName.isEmpty ? 'Student' : profile.fullName,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                profile.email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => _openEditProfile(profile),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityCard(
    UserProfile profile,
    int semester,
    int year,
    ThemeData theme,
  ) {
    final degreeDisplay = profile.degree.isEmpty
        ? 'Degree not set'
        : profile.degree;
    final branchDisplay = profile.branch.isEmpty
        ? 'Branch not set'
        : profile.branch;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academic profile',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$degreeDisplay - $branchDisplay',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_yearLabel(year)} - Semester $semester',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicDetails(
    UserProfile profile,
    int semester,
    int year,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Student details',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth < 620 ? 1 : 2;

            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: crossAxisCount == 1 ? 5.2 : 3.8,
              children: [
                _buildDetailTile(
                  Icons.school_outlined,
                  'Degree',
                  profile.degree.isEmpty ? 'Not set' : profile.degree,
                  theme,
                ),
                _buildDetailTile(
                  Icons.account_tree_outlined,
                  'Branch',
                  profile.branch.isEmpty ? 'Not set' : profile.branch,
                  theme,
                ),
                _buildDetailTile(
                  Icons.schedule_outlined,
                  'Semester',
                  semester.toString(),
                  theme,
                ),
                _buildDetailTile(
                  Icons.badge_outlined,
                  'Roll number',
                  profile.sid.isEmpty ? 'Not set' : profile.sid,
                  theme,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetailTile(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedAccountsCard(UserProfile profile, ThemeData theme) {
    final connected = profile.oauthConnected;
    final statusColor = Colors.green;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connected accounts',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.mail_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gmail',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      connected ? 'Connected' : 'Not connected',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: connected ? statusColor : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                connected ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                color: connected ? statusColor : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                size: 20,
              ),
            ],
          ),
          if (connected) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Disconnect Gmail?'),
                      content: const Text(
                        'This will stop syncing your emails and disconnect your Gmail account from Uni-Dash. You can reconnect anytime.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          child: const Text('Disconnect'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && mounted) {
                    try {
                      await BackendService.disconnectGoogleOAuth();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Gmail disconnected successfully'),
                          ),
                        );
                        setState(() {
                          _profileFuture = _fetchProfile();
                        });
                        Navigator.of(context).pop(true);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to disconnect Gmail: $e'),
                          ),
                        );
                      }
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Disconnect Gmail'),
              ),
            ),
          ],
          if (profile.reauthRequired && profile.reauthReason != null) ...[
            const SizedBox(height: 14),
            Text(
              profile.reauthReason!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountActionsCard(ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout?'),
                    content: const Text(
                      'You will be signed out from Uni-Dash. You can sign back in anytime.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true && mounted) {
                  // Show loading snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logging out...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  try {
                    await BackendService.logout();
                    if (mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Logout failed: $e'),
                        ),
                      );
                    }
                  }
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }

}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: child,
    );
  }
}
