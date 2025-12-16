
			class UserProfile {
				final String uid;
				final String email;
				final String name;
				final String branch;
				final int semester;
				final String sid;
				final bool profileCompleted;
				final bool oauthConnected;

				UserProfile({
					required this.uid,
					required this.email,
					required this.name,
					required this.branch,
					required this.semester,
					required this.sid,
					required this.profileCompleted,
					required this.oauthConnected,
				});

				factory UserProfile.fromJson(Map<String, dynamic> json) {
					int parseSemester(dynamic value) {
						if (value is int) return value;
						if (value is String) return int.tryParse(value) ?? 0;
						return 0;
					}
					return UserProfile(
						uid: json['uid'] as String? ?? '',
						email: json['email'] as String? ?? '',
						name: json['name'] as String? ?? '',
						branch: json['branch'] as String? ?? '',
						semester: parseSemester(json['semester']),
						sid: json['sid'] as String? ?? '',
						profileCompleted: json['profile_completed'] == true || json['profile_completed'] == 1,
						oauthConnected: json['oauth_connected'] == true || json['oauth_connected'] == 1,
					);
				}

				Map<String, dynamic> toJson() {
					return {
						'uid': uid,
						'email': email,
						'name': name,
						'branch': branch,
						'semester': semester,
						'sid': sid,
						'profile_completed': profileCompleted,
						'oauth_connected': oauthConnected,
					};
				}
			}
