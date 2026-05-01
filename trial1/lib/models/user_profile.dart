class UserProfile {
  final String uid;
  final String email;
  final String fullName;
  final String degree;
  final String branch;
  final int admissionYear;
  final String sid;
  final bool profileCompleted;
  final bool oauthConnected;
  final bool adminConnected;
  final bool reauthRequired;
  final String? reauthReason;

  UserProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.degree,
    required this.branch,
    required this.admissionYear,
    required this.sid,
    required this.profileCompleted,
    required this.oauthConnected,
    required this.adminConnected,
    required this.reauthRequired,
    this.reauthReason,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      degree: json['degree'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      admissionYear: json['admission_year'] is int
          ? json['admission_year'] as int
          : int.tryParse(json['admission_year']?.toString() ?? '') ?? 0,
      sid: json['sid'] as String? ?? '',
      profileCompleted: json['profile_completed'] == true || json['profile_completed'] == 1,
      oauthConnected: json['oauth_connected'] == true || json['oauth_connected'] == 1,
      adminConnected: json['admin_connected'] == true || json['admin_connected'] == 1,
      reauthRequired: json['reauth_required'] == true || json['reauth_required'] == 1,
      reauthReason: json['reauth_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'full_name': fullName,
      'degree': degree,
      'branch': branch,
      'admission_year': admissionYear,
      'sid': sid,
      'profile_completed': profileCompleted,
      'oauth_connected': oauthConnected,
      'admin_connected': adminConnected,
      'reauth_required': reauthRequired,
      'reauth_reason': reauthReason,
    };
  }
}

