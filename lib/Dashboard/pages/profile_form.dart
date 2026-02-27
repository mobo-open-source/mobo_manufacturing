import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/company/session/company_session_manager.dart';
import '../../globals.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';
import '../../shared/widgets/snackbar.dart';

/// Full-screen form for viewing and editing the current user's profile.
///
/// Features:
/// - Display current profile data (name, email, phone, address, job title, etc.)
/// - Edit mode (toggle via "Edit" button — admin only)
/// - Profile picture upload from gallery or camera
/// - Address editing popup with country/state dropdowns
/// - Real-time save with success/error feedback
/// - Shimmer loading state + admin permission check
///
/// Only users with `base.group_system` (admin) can edit fields.
class ProfileFormPage extends StatefulWidget {
  /// Callback to refresh parent screen profile data after changes
  final Future<void> Function()? refreshProfile;

  const ProfileFormPage({super.key, this.refreshProfile});

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  List<Profile> profiles = [];
  Uint8List? profileImageBytes;
  String? base64Image;
  File? _pickedImageFile;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _companyController = TextEditingController();
  final _mobileController = TextEditingController();
  final _websiteController = TextEditingController();
  final _jobTitleController = TextEditingController();
  List<Map<String, dynamic>> states = [];
  List<Map<String, dynamic>> countries = [];
  final _picker = ImagePicker();
  bool isEdited = false;
  final _street1Controller = TextEditingController();
  final _street2Controller = TextEditingController();
  int? selectedStateId;
  Map<String, dynamic>? selectedState;
  int? selectedCountryId;
  Map<String, dynamic>? selectedCountry;
  bool isLoading = true;
  bool isSaving = false;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    canManageSkills();
    loadProfile();
  }

  /// Parses major version number from server version string (e.g. "16.0" → 16)
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Checks if current user is admin (has `base.group_system`) to enable editing.
  ///
  /// Uses different `has_group` call format based on Odoo server version.
  Future<void> canManageSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final String version = prefs.getString('serverVersion') ?? '0';
    final int userId = prefs.getInt('userId') ?? 0;
    final int majorVersion = parseMajorVersion(version);

    Future<bool> hasGroup(String groupExtId) async {
      if (majorVersion >= 18) {
        return await CompanySessionManager.callKwWithCompany({
              'model': 'res.users',
              'method': 'has_group',
              'args': [userId, groupExtId],
              'kwargs': {},
            }) ==
            true;
      } else {
        return await CompanySessionManager.callKwWithCompany({
              'model': 'res.users',
              'method': 'has_group',
              'args': [groupExtId],
              'kwargs': {},
            }) ==
            true;
      }
    }

    final admin = await hasGroup('base.group_system');

    setState(() {
      isAdmin = admin;
    });
  }

  /// Loads current user profile, countries, and states from backend.
  ///
  /// Populates form fields and profile image if available.
  Future<void> loadProfile() async {
    final profileService = ProfileService();
    await profileService.initializeClient();
    profiles = await profileService.loadProfile();

    countries = await profileService.fetchCountries();
    states = await profileService.fetchStates();
    if (profiles.isNotEmpty) {
      final profile = profiles.first;
      _nameController.text = profile.name;
      _emailController.text = profile.mail;
      _phoneController.text = profile.phone;
      _addressController.text = profile.address;
      _companyController.text = profile.company;
      _mobileController.text = profile.mobile;
      _websiteController.text = profile.website;
      _jobTitleController.text = profile.jobTitle;
      _street1Controller.text = profile.street;
      _street2Controller.text = profile.street2;
      selectedState = {'id': profile.stateId, 'name': profile.state};

      selectedCountry = {'id': profile.countryId, 'name': profile.country};

      if (profile.image.isNotEmpty) {
        setState(() {
          profileImageBytes = base64Decode(profile.image);
        });
        base64Image = profile.image;
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  /// Opens image picker (gallery/camera) and uploads new avatar.
  Future<void> _pickImage() async {
    final profileService = ProfileService();
    await profileService.initializeClient();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        profileImageBytes = bytes;
        base64Image = base64String;
        isEdited = true;
      });
      await profileService.updateUserProfile({'image_1920': base64String});
    }
  }

  /// Saves all editable profile fields to backend.
  Future<void> _saveProfile() async {
    setState(() {
      isSaving = true;
    });
    final prefs = await SharedPreferences.getInstance();
    int version = prefs.getInt('version') ?? 0;

    final profileService = ProfileService();
    await profileService.initializeClient();
    final updateData = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'contact_address': _addressController.text.trim(),
      'image_1920': base64Image ?? _pickedImageFile ?? "",
      if (version < 18) 'mobile': _mobileController.text.trim(),
      if (version >= 18) 'mobile_phone': _mobileController.text.trim(),
    };

    final success = await profileService.updateUserProfile(updateData);
    if (success) {
      setState(() {
        isEdited = false;
        isSaving = false;
      });

      CustomSnackbar.showSuccess(context, 'Profile saved successfully');
    } else {
      setState(() {
        isEdited = false;
        isSaving = false;
      });
      CustomSnackbar.showError(context, 'Failed to save profile');
    }
    setState(() {
      isEdited = false;
      isSaving = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        await widget.refreshProfile?.call();
        return true;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          elevation: 0,
          title: Text(
            'Profile Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
              size: 28,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              if (widget.refreshProfile != null) widget.refreshProfile!();
            },
          ),
          actions: [
            if (isAdmin) ...[
              if (isEdited == false)
                TextButton(
                  onPressed: () {
                    setState(() => isEdited = true);
                  },
                  child: Text(
                    "Edit",
                    style: TextStyle(
                      color: theme.colorScheme.onBackground,
                      fontWeight: FontWeight.w500,
                      fontSize: 17,
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => isEdited = false);
                      },
                      child: Text(
                        "cancel",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: isEdited ? _saveProfile : null,
                      child: Text(
                        "Save",
                        style: TextStyle(
                          color: theme.colorScheme.onBackground,
                          fontWeight: FontWeight.w500,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
        body: isLoading
            ? _buildShimmerLoading()
            : Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: isEdited ? _pickImage : null,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundImage: _pickedImageFile != null
                                      ? FileImage(_pickedImageFile!)
                                      : (profileImageBytes != null
                                            ? MemoryImage(profileImageBytes!)
                                            : null),
                                  child:
                                      _pickedImageFile == null &&
                                          profileImageBytes == null
                                      ? Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                                if (isEdited)
                                  Positioned(
                                    child: InkWell(
                                      onTap: _showImageSourceActionSheet,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppStyle.primaryColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.grey[900]!
                                                : Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          HugeIcons.strokeRoundedCamera02,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Text(
                          "Personal Information",
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoField(
                          Icons.person_outline,
                          "Full Name",
                          _nameController,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoField(
                          Icons.email_outlined,
                          "Email",
                          _emailController,
                        ),
                        const SizedBox(height: 8),

                        _buildInfoField(
                          Icons.phone_outlined,
                          "Phone",
                          _phoneController,
                        ),
                        const SizedBox(height: 8),

                        _buildInfoField(
                          Icons.phone_android_outlined,
                          "Mobile",
                          _mobileController,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoField(
                          Icons.language_outlined,
                          "Website",
                          _websiteController,
                          editable: false,
                        ),
                        const SizedBox(height: 8),

                        _buildInfoField(
                          Icons.work_outline,
                          "Job Title",
                          _jobTitleController,
                          editable: false,
                        ),
                        const SizedBox(height: 8),
                        _buildReadOnlyTextField(
                          Icons.apartment_outlined,
                          "Company",
                          _companyController,
                        ),
                        const SizedBox(height: 8),
                        _buildEditableDetailField(
                          Icons.home,
                          'Address',
                          _addressController,
                          onEdit: () => _showEditPopup(),
                        ),
                      ],
                    ),
                  ),
                  if (isSaving)
                    Positioned.fill(
                      child: Center(
                        child: LoadingAnimationWidget.fourRotatingDots(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          size: 50,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  /// Shows bottom sheet to choose image source (camera / gallery)
  void _showImageSourceActionSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      HugeIcons.strokeRoundedCamera02,
                      size: 24,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Take Photo',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.gallery);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      HugeIcons.strokeRoundedImageCrop,
                      size: 24,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Choose from Gallery',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Picks image from specified source and updates preview + base64
  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 600,
      );
      if (picked == null || !mounted) return;

      setState(() => _pickedImageFile = File(picked.path));
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() => base64Image = base64Encode(bytes));

      if (mounted) {
        _showSuccessSnackBar('Image updated successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update image: $e');
      }
    }
  }

  void _showSuccessSnackBar(String msg) {
    CustomSnackbar.showSuccess(context, msg);
  }

  void _showErrorSnackBar(String msg) {
    CustomSnackbar.showError(context, msg);
  }

  /// Builds editable or read-only field based on `isEdited` state
  Widget _buildInfoField(
    IconData icon,
    String label,
    TextEditingController controller, {
    bool editable = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = (controller.text.isEmpty)
        ? "Not set"
        : controller.text;

    if (isEdited && editable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: TextStyle(fontWeight: FontWeight.w400).fontFamily,
              color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
              border: Border.all(color: Colors.transparent, width: 1),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: controller.text.isEmpty ? 'Enter $label' : null,
                hintStyle: TextStyle(
                  fontFamily: TextStyle(fontWeight: FontWeight.w600).fontFamily,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  height: 1.0,
                ),
                prefixIcon: Icon(
                  icon,
                  color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.transparent,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: TextStyle(fontWeight: FontWeight.w400).fontFamily,
              color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
              border: Border.all(color: Colors.transparent, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 15,
                      color: displayValue == 'Not set'
                          ? (isDark ? Colors.grey[500]! : Colors.grey[500]!)
                          : (isDark ? Colors.white70 : Colors.black),
                      fontWeight: displayValue == "Not set"
                          ? FontWeight.w400
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  /// Read-only styled field (used for company, etc.)
  Widget _buildReadOnlyTextField(
    IconData icon,
    String label,
    TextEditingController controller,
  ) {
    final displayValue = (controller.text.isEmpty)
        ? "Not set"
        : controller.text;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w400,
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
            border: Border.all(color: Colors.transparent, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayValue,
                          style: TextStyle(
                            fontSize: 15,
                            color: displayValue == 'Not set'
                                ? (isDark
                                      ? Colors.grey[500]!
                                      : Colors.grey[500]!)
                                : (isDark
                                      ? Colors.white70
                                      : const Color(0xff000000)),
                            fontWeight: displayValue == "Not set"
                                ? FontWeight.w400
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Address field with edit icon that opens popup
  Widget _buildEditableDetailField(
    IconData icon,
    String label,
    TextEditingController controller, {
    required VoidCallback onEdit,
  }) {
    final value = controller.text.isNotEmpty
        ? controller.text
        : 'Tap to add $label';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
              border: Border.all(color: Colors.transparent, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        color: controller.text.isNotEmpty
                            ? (isDark ? Colors.white70 : Colors.black)
                            : Colors.grey,
                        fontWeight: controller.text.isNotEmpty
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit,
                    size: 18,
                    color: isDark ? Colors.white70 : AppStyle.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Popup dialog to edit detailed address (street1, street2, state, country)
  Future<void> _showEditPopup() async {
    await showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        bool isCountryDropdownOpen = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Address Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : AppStyle.primaryColor,
                    ),
                  ),
                ],
              ),
              content: Stack(
                children: [
                  SizedBox(
                    height:
                        MediaQuery.of(context).size.height *
                        (isCountryDropdownOpen ? 0.60 : 0.42),
                    width: MediaQuery.of(context).size.width * 0.95,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Street 1',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xff7F7F7F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xffF8FAFB),
                              border: Border.all(
                                color: Colors.transparent,
                                width: 1,
                              ),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: TextField(
                              controller: _street1Controller,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                hintText: 'Enter Street 1',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                  height: 1.0,
                                ),
                                prefixIcon: Icon(
                                  HugeIcons.strokeRoundedNavigator01,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xff7F7F7F),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white
                                        : AppStyle.primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Street 2',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xff7F7F7F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xffF8FAFB),
                              border: Border.all(
                                color: Colors.transparent,
                                width: 1,
                              ),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: TextField(
                              controller: _street2Controller,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                hintText: 'Enter Street 2',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                  height: 1.0,
                                ),
                                prefixIcon: Icon(
                                  HugeIcons.strokeRoundedNavigator01,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xff7F7F7F),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white
                                        : AppStyle.primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'State',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xff7F7F7F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xffF8FAFB),
                              border: Border.all(
                                color: Colors.transparent,
                                width: 1,
                              ),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: DropdownSearch<Map<String, dynamic>>(
                              popupProps: PopupProps.menu(
                                showSearchBox: true,
                                menuProps: MenuProps(
                                  backgroundColor: isDark
                                      ? Colors.black
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  elevation: 4,
                                ),
                                searchFieldProps: TextFieldProps(
                                  style: TextStyle(fontWeight: FontWeight.w400),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    labelText: "Search State",
                                    labelStyle: TextStyle(
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                      fontSize: 14,
                                      height: 1.0,
                                    ),
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              items: states,
                              itemAsString: (item) => item['name'] ?? '',
                              selectedItem: selectedState,
                              onChanged: (value) {
                                setState(() {
                                  selectedState = value;
                                  selectedStateId = value?['id'];
                                });
                              },
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  hintText: 'Select State',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                    height: 1.0,
                                  ),
                                  prefixIcon: Icon(
                                    HugeIcons.strokeRoundedRoadLocation01,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white
                                          : AppStyle.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Country',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xff7F7F7F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xffF8FAFB),
                              border: Border.all(
                                color: Colors.transparent,
                                width: 1,
                              ),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: DropdownSearch<Map<String, dynamic>>(
                              popupProps: PopupProps.menu(
                                showSearchBox: true,
                                onDismissed: () {
                                  setDialogState(
                                    () => isCountryDropdownOpen = false,
                                  );
                                },
                                menuProps: MenuProps(
                                  backgroundColor: isDark
                                      ? Colors.black
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  elevation: 4,
                                ),
                                searchFieldProps: TextFieldProps(
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    labelText: "Search Country",
                                    labelStyle: TextStyle(
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                      fontSize: 14,
                                      height: 1.0,
                                    ),
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              onBeforePopupOpening: (selectedState) async {
                                setDialogState(
                                  () => isCountryDropdownOpen = true,
                                );
                                return true;
                              },
                              items: countries,
                              itemAsString: (item) => item['name'] ?? '',
                              selectedItem: selectedCountry,
                              onChanged: (value) {
                                setState(() {
                                  selectedCountry = value;
                                  selectedCountryId = value?['id'];
                                });
                              },
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  hintText: 'Select Country',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                    height: 1.0,
                                  ),
                                  prefixIcon: Icon(
                                    HugeIcons.strokeRoundedFlag02,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white
                                          : AppStyle.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isSaving)
                    Positioned.fill(
                      child: Center(
                        child: LoadingAnimationWidget.fourRotatingDots(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          size: 50,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white
                              : Colors.black87,
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.white,
                          side: BorderSide(
                            color: isDark ? Colors.white : Color(0xFFBB2649),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text(
                          "CANCEL",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          setDialogState(() {
                            isSaving = true;
                          });
                          final profileService = ProfileService();
                          await profileService.initializeClient();
                          final updateData = {
                            'street': _street1Controller.text,
                            'street2': _street2Controller.text,
                            'state_id': selectedStateId,
                            'country_id': selectedCountryId,
                          };
                          final success = await profileService
                              .updateUserAddress(updateData);
                          if (success) {
                            profiles = await profileService.loadProfile();
                            final profile = profiles.first;

                            setState(() {
                              _nameController.text = profile.name;
                              _emailController.text = profile.mail;
                              _phoneController.text = profile.phone;
                              _addressController.text = profile.address;
                              _companyController.text = profile.company;
                              _street1Controller.text = profile.street;
                              _street2Controller.text = profile.street2;
                              selectedState = {
                                'id': profile.stateId,
                                'name': profile.state,
                              };

                              selectedCountry = {
                                'id': profile.countryId,
                                'name': profile.country,
                              };
                              isEdited = true;
                            });
                            setDialogState(() {
                              isSaving = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green,
                                content: Text(
                                  'Address updated successfully',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } else {
                            setDialogState(() {
                              isSaving = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red,
                                content: Text(
                                  'Failed to update address',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white
                              : AppStyle.primaryColor,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'SAVE',
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shimmer loading UI for profile form
  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _shimmerBox(height: 50),
          const SizedBox(height: 12),
          _shimmerBox(height: 80),
          const SizedBox(height: 12),
          _shimmerBox(height: 50),
          const SizedBox(height: 12),
          _shimmerBox(height: 50),
          const SizedBox(height: 12),
          _shimmerBox(height: 50),
        ],
      ),
    );
  }

  Widget _shimmerBox({double height = 50}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
