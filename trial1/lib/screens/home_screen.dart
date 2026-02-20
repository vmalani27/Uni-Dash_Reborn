import 'package:flutter/material.dart';
import 'package:trial1/screens/profile_screen.dart';
import 'package:trial1/models/UserProfile.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/widgets/gmail_notifications_list.dart';
import 'package:trial1/widgets/skeleton_loader.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    if (_profile == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await BackendService.fetchUserProfile();
      if (mounted) {
        setState(() {
          _profile = UserProfile.fromJson(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load profile. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _profile?.name.split(' ').first ?? 'Student';

    return Scaffold(
      backgroundColor: kBgPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: kBgPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            floating: true,
            snap: true,
            toolbarHeight: 60,
            title: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: () => _navigateToProfile(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kAccentPrimary, kAccentSecondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        firstName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hi, $firstName',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Your academic inbox',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: kTextSecondary,
                  size: 22,
                ),
                onPressed: _navigateToProfile,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _profile == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 0),
        child: SkeletonNotificationList(),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_profile != null && _profile!.oauthConnected) {
      return const GmailNotificationsList();
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildOAuthPrompt(),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    ).then((_) => _fetchProfile());
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kUrgencyCritical.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: kUrgencyCritical.withOpacity(0.7),
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchProfile,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOAuthPrompt() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kBgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kAccentPrimary.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kAccentPrimary.withOpacity(0.15),
                    kAccentSecondary.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.mail_outline,
                color: kAccentPrimary,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Connect Gmail',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Link your university email to get AI-powered notifications, deadline tracking, and smart organization.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToProfile,
                child: const Text('Connect Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
