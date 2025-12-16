import 'package:flutter/material.dart';
import 'package:trial1/models/UserProfile.dart';
import 'package:trial1/services/api_services.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: FutureBuilder<UserProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Failed to load profile:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No profile data found.'));
          }
          final profile = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            children: [
              CircleAvatar(
                radius: 38,
                child: Text(
                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 18),
              _profileField('Name', profile.name),
              _profileField('Email', profile.email),
              _profileField('Branch', profile.branch),
              _profileField('Semester', profile.semester.toString()),
              _profileField('Roll Number', profile.sid),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text('Profile Completed:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Icon(
                    profile.profileCompleted ? Icons.check_circle : Icons.cancel,
                    color: profile.profileCompleted ? Colors.green : Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!profile.oauthConnected)
                ElevatedButton(
                  onPressed: () async {
                    await BackendService.startGoogleOAuth(
                     
                    );
                    setState(() {
                      _profileFuture = _fetchProfile();
                    });
                  },
                  child: const Text('Connect Google Account'),
                ),
              if (profile.oauthConnected)
                Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('Google Account Connected', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _profileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
