import 'package:flutter/material.dart';
import 'package:trial1/screens/connect_gmail_screen.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/models/user_profile.dart';

enum ProfileFormMode {
  create,
  edit,
}

class ProfileFormScreen extends StatefulWidget {
  final ProfileFormMode mode;
  final UserProfile? profile;
  final VoidCallback? onProfileUpdated;
  const ProfileFormScreen({
    super.key,
    required this.mode,
    this.profile,
    this.onProfileUpdated,
  });

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<String> degreeOptions = ['BTech', 'MTech', 'BSc', 'MSc'];
  final List<String> branchOptions = ['CSE', 'IT', 'ECE', 'Mechanical', 'Civil', 'Electrical', 'Other'];
  late TextEditingController fullNameController;
  late TextEditingController admissionYearController;
  late TextEditingController rollController;
  String? selectedDegree;
  String? selectedBranch;
  bool _isLoading = false;
  String? _errorMessage;

  // Normalize degree values from backend
  String _normalizeDegree(String? value) {
    if (value == null) return '';
    final normalized = value.replaceFirst(value[0], value[0].toUpperCase());
    if (normalized == 'Btech') return 'BTech';
    if (normalized == 'Mtech') return 'MTech';
    if (normalized == 'Bsc') return 'BSc';
    if (normalized == 'Msc') return 'MSc';
    return normalized;
  }

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    final isEdit = widget.mode == ProfileFormMode.edit;
    
    if (isEdit && profile != null) {
      fullNameController = TextEditingController(text: profile.fullName);
      admissionYearController = TextEditingController(text: profile.admissionYear.toString());
      rollController = TextEditingController(text: profile.sid);
      selectedDegree = _normalizeDegree(profile.degree);
      selectedBranch = profile.branch;
    } else {
      fullNameController = TextEditingController();
      admissionYearController = TextEditingController();
      rollController = TextEditingController();
      selectedDegree = null;
      selectedBranch = null;
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    admissionYearController.dispose();
    rollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final cardWidth = isMobile ? constraints.maxWidth * 0.92 : 440.0;
          return Center(
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 400),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: cardWidth,
                ),
                child: Card(
                  color: colorScheme.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.8),
                      width: 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 20 : 32,
                      horizontal: isMobile ? 18 : 32,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Complete Your Profile',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We need a few details to personalize your experience',
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          _buildTextField(
                            controller: fullNameController,
                            label: 'Full Name',
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter your full name';
                              }
                              return null;
                            },
                            autoFocus: true,
                            enabled: widget.mode == ProfileFormMode.create,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: selectedDegree,
                            items: degreeOptions
                                .map((deg) => DropdownMenuItem(value: deg, child: Text(deg)))
                                .toList(),
                            onChanged: widget.mode == ProfileFormMode.create
                                ? (val) => setState(() => selectedDegree = val)
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Degree',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Select your degree' : null,
                            disabledHint: selectedDegree != null ? Text(selectedDegree!) : null,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: selectedBranch,
                            items: branchOptions
                                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                .toList(),
                            onChanged: (val) => setState(() => selectedBranch = val),
                            decoration: InputDecoration(
                              labelText: 'Branch',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Select your branch' : null,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: admissionYearController,
                            label: 'Admission Year',
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter your admission year';
                              }
                              final year = int.tryParse(v);
                              if (year == null || year < 2000 || year > DateTime.now().year) {
                                return 'Enter a valid year';
                              }
                              return null;
                            },
                            enabled: true,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: rollController,
                            label: 'Roll Number',
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter roll number';
                              }
                              return null;
                            },
                            enabled: widget.mode == ProfileFormMode.create,
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colorScheme.error.withValues(alpha: 0.28),
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
                          const SizedBox(height: 26),
                          if (widget.mode == ProfileFormMode.create)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
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
                                    : const Text('Continue'),
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: colorScheme.onSurface,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: colorScheme.outline),
                                      ),
                                      textStyle: textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    child: const Text('Discard'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleSubmit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
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
                                        : const Text('Save'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool autoFocus = false,
    bool enabled = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autoFocus,
      enabled: enabled,
      style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.12)),
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
        if (widget.mode == ProfileFormMode.create) {
          await BackendService.createUserProfile(
            fullName: fullNameController.text.trim(),
            degree: selectedDegree ?? '',
            branch: selectedBranch ?? '',
            admissionYear: int.parse(admissionYearController.text.trim()),
            sid: rollController.text.trim(),
          );
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const ConnectGmailScreen(),
              ),
            );
          }
        } else {
          final yearStr = admissionYearController.text.trim();
          final year = yearStr.isNotEmpty ? int.tryParse(yearStr) : null;
          await BackendService.updateUserProfile(
            branch: selectedBranch,
            admissionYear: year,
          );
          if (mounted) {
            widget.onProfileUpdated?.call();
            Navigator.of(context).pop();
          }
        }
      } on FormatException {
        setState(() {
          _errorMessage = 'Invalid input. Please check your entries.';
          _isLoading = false;
        });
      } catch (e) {
        String errorMessage = 'Failed to save profile. Please try again.';
        
        // Try to parse backend validation errors
        if (e.toString().contains('422')) {
          errorMessage = 'Validation error. Please check your inputs.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (e.toString().contains('401') || e.toString().contains('403')) {
          errorMessage = 'Authentication failed. Please log in again.';
        }
        
        setState(() {
          _errorMessage = errorMessage;
          _isLoading = false;
        });
      }
    }
  }
}

