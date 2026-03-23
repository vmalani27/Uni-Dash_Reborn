import 'package:flutter/material.dart';
import 'package:trial1/screens/home_screen.dart';
import 'package:trial1/services/api_services.dart';

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback? themeToggle;
  final ThemeMode? themeMode;
  const ProfileSetupScreen({super.key, this.themeToggle, this.themeMode});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final branchController = TextEditingController();
  final semesterController = TextEditingController();
  final rollController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    nameController.dispose();
    branchController.dispose();
    semesterController.dispose();
    rollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(
          'Complete Your Profile',
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Card(
            color: colorScheme.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tell us about yourself',
                      style: textTheme.titleLarge?.copyWith(fontSize: 20, color: colorScheme.onSurface),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We need these details to personalize your experience',
                      style: textTheme.bodyMedium?.copyWith(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _buildTextField(
                      controller: nameController,
                      label: 'Full Name',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: branchController,
                      label: 'Branch / Program',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your branch/program';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: semesterController,
                      label: 'Semester / Year',
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter semester/year'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: rollController,
                      label: 'Roll Number',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter roll number';
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.error.withOpacity(0.28),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: colorScheme.onPrimary,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
      validator: validator,
    );
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await BackendService.createUserProfile(
          name: nameController.text.trim(),
          branch: branchController.text.trim(),
          semester: semesterController.text.trim(),
          sid: rollController.text.trim(),
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to create profile. Please try again.';
          _isLoading = false;
        });
      }
    }
  }
}
