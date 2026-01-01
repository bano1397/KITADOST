import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

class FormFieldConfig {
  final String label;
  final String key;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final String? prefix;
  final bool required;
  final String? Function(String?)? validator;
  final bool isDropdown;
  final List<String>? dropdownOptions;
  final bool isDatePicker;

  FormFieldConfig({
    required this.label,
    required this.key,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.prefix,
    this.required = true,
    this.validator,
    this.isDropdown = false,
    this.dropdownOptions,
    this.isDatePicker = false,
  });
}

class EditBookPostingForm extends StatefulWidget {
  final Map<String, dynamic> book;
  final String bookId;

  const EditBookPostingForm({
    Key? key,
    required this.book,
    required this.bookId,
  }) : super(key: key);

  @override
  State<EditBookPostingForm> createState() => _EditBookPostingFormState();
}

class _EditBookPostingFormState extends State<EditBookPostingForm> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  File? _bookImage;
  String? _bookImageBase64;
  bool _imageChanged = false;
  
  // Dynamic form data storage
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _formData = {};

  // Dynamic form configuration
  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Book Details',
      'fields': [
        FormFieldConfig(
          label: 'Book Title',
          key: 'title',
          icon: Icons.auto_stories_rounded,
        ),
        FormFieldConfig(
          label: 'Book Genre/Category',
          key: 'genre',
          icon: Icons.local_library_rounded,
          isDropdown: true,
          dropdownOptions: ['Education', 'Fiction', 'Non - Fiction', 'Mystery'],
        ),
        FormFieldConfig(
          label: 'Author',
          key: 'author',
          icon: Icons.edit_rounded,
        ),
        FormFieldConfig(
          label: 'Publication',
          key: 'publication',
          icon: Icons.apartment_rounded,
          required: false,
        ),
        FormFieldConfig(
          label: 'Language',
          key: 'language',
          icon: Icons.translate_rounded,
          isDropdown: true,
          dropdownOptions: ['English', 'Filipino', 'Spanish', 'Chinese', 'Japanese', 'Korean', 'Other'],
        ),
        FormFieldConfig(
          label: 'Condition',
          key: 'condition',
          icon: Icons.verified_rounded,
          isDropdown: true,
          dropdownOptions: ['Brand New', 'Good as New', 'Old (Used)'],
        ),
        FormFieldConfig(
          label: 'Publication Date',
          key: 'year',
          icon: Icons.event_rounded,
          keyboardType: TextInputType.datetime,
          isDatePicker: true,
          required: false,
          validator: (value) {
            if (value == null || value.isEmpty) return null; // Optional field
            // Validate format mm/dd/yyyy
            final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
            if (!dateRegex.hasMatch(value)) {
              return 'Please enter date in format mm/dd/yyyy';
            }
            try {
              final parts = value.split('/');
              final month = int.parse(parts[0]);
              final day = int.parse(parts[1]);
              final year = int.parse(parts[2]);
              
              if (month < 1 || month > 12) return 'Invalid month';
              if (day < 1 || day > 31) return 'Invalid day';
              if (year < 1000 || year > DateTime.now().year) {
                return 'Year must be between 1000 and ${DateTime.now().year}';
              }
              
              final date = DateTime(year, month, day);
              if (date.isAfter(DateTime.now())) {
                return 'Date cannot be in the future';
              }
            } catch (e) {
              return 'Invalid date';
            }
            return null;
          },
        ),
        FormFieldConfig(
          label: 'Publisher',
          key: 'publisher',
          icon: Icons.domain_rounded,
          required: false,
        ),
        FormFieldConfig(
          label: 'About',
          key: 'about',
          icon: Icons.article_rounded,
          maxLines: 4,
        ),
        FormFieldConfig(
          label: 'Library Pickup Location',
          key: 'pickupLocation',
          icon: Icons.location_on_rounded,
          maxLines: 2,
          required: true,
        ),
        FormFieldConfig(
          label: 'Map Link (Google Maps URL)',
          key: 'mapLink',
          icon: Icons.map_rounded,
          maxLines: 2,
          required: false,
          keyboardType: TextInputType.url,
          validator: (value) {
            if (value == null || value.isEmpty) return null; // Optional field
            // Basic URL validation
            final urlPattern = RegExp(
              r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
            );
            if (!urlPattern.hasMatch(value)) {
              return 'Please enter a valid URL (e.g., https://maps.google.com/...)';
            }
            return null;
          },
        ),
      ],
    },
    {
      'title': 'Penalties',
      'subtitle': 'Set penalty amounts for book violations',
      'fields': [
        FormFieldConfig(
          label: 'Late Return',
          key: 'late_return',
          icon: Icons.access_time_rounded,
          keyboardType: TextInputType.number,
          prefix: '₱',
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter Late Return penalty';
            final amount = double.tryParse(value);
            if (amount == null || amount < 0) return 'Please enter a valid amount';
            return null;
          },
        ),
        FormFieldConfig(
          label: 'Book Damage',
          key: 'damage',
          icon: Icons.report_problem_rounded,
          keyboardType: TextInputType.number,
          prefix: '₱',
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter Book Damage penalty';
            final amount = double.tryParse(value);
            if (amount == null || amount < 0) return 'Please enter a valid amount';
            return null;
          },
        ),
        FormFieldConfig(
          label: 'Lost or Unreturned Book',
          key: 'lost',
          icon: Icons.search_off_rounded,
          keyboardType: TextInputType.number,
          prefix: '₱',
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter Lost Book penalty';
            final amount = double.tryParse(value);
            if (amount == null || amount < 0) return 'Please enter a valid amount';
            return null;
          },
        ),
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadExistingData();
  }

  void _initializeControllers() {
    for (var step in _steps) {
      final fields = step['fields'] as List<FormFieldConfig>;
      for (var field in fields) {
        _controllers[field.key] = TextEditingController();
      }
    }
  }

  void _loadExistingData() {
    // Load existing book data into controllers
    _controllers['title']?.text = widget.book['title'] ?? '';
    _controllers['genre']?.text = widget.book['genre'] ?? '';
    _controllers['author']?.text = widget.book['author'] ?? '';
    _controllers['publication']?.text = widget.book['publication'] ?? '';
    _controllers['language']?.text = widget.book['language'] ?? '';
    _controllers['condition']?.text = widget.book['condition'] ?? '';
    _controllers['year']?.text = widget.book['year'] ?? '';
    _controllers['publisher']?.text = widget.book['publisher'] ?? '';
    _controllers['about']?.text = widget.book['about'] ?? '';
    _controllers['pickupLocation']?.text = widget.book['pickupLocation'] ?? '';
    _controllers['mapLink']?.text = widget.book['mapLink'] ?? '';

    // Load penalties
    if (widget.book['penalties'] != null) {
      final penalties = widget.book['penalties'] as Map;
      _controllers['late_return']?.text = (penalties['lateReturn'] ?? 0).toString();
      _controllers['damage']?.text = (penalties['damage'] ?? 0).toString();
      _controllers['lost']?.text = (penalties['lost'] ?? 0).toString();
    }

    // Load existing image
    if (widget.book['imageUrl'] != null && (widget.book['imageUrl'] as String).isNotEmpty) {
      _bookImageBase64 = widget.book['imageUrl'];
    }

    // Set initial form data
    _formData['genre'] = widget.book['genre'];
    _formData['condition'] = widget.book['condition'];
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      // Save current step data
      _saveCurrentStepData();

      if (_currentStep < _steps.length - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        _submitForm();
      }
    }
  }

  void _saveCurrentStepData() {
    final fields = _steps[_currentStep]['fields'] as List<FormFieldConfig>;
    for (var field in fields) {
      _formData[field.key] = _controllers[field.key]!.text;
    }
  }

  Future<void> _submitForm() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to edit books'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final database = FirebaseDatabase.instance;
      final bookRef = database.ref('books/${widget.bookId}');

      // Prepare updated book data
      final updatedData = {
        'title': _formData['title'] ?? '',
        'genre': _formData['genre'] ?? '',
        'author': _formData['author'] ?? '',
        'publication': _formData['publication'] ?? '',
        'language': _formData['language'] ?? '',
        'condition': _formData['condition'] ?? '',
        'year': _formData['year'] ?? '',
        'publisher': _formData['publisher'] ?? '',
        'about': _formData['about'] ?? '',
        'pickupLocation': _formData['pickupLocation'] ?? '',
        'mapLink': _formData['mapLink'] ?? '',
        'penalties': {
          'lateReturn': double.tryParse(_formData['late_return'] ?? '0') ?? 0.0,
          'damage': double.tryParse(_formData['damage'] ?? '0') ?? 0.0,
          'lost': double.tryParse(_formData['lost'] ?? '0') ?? 0.0,
        },
        'updatedAt': ServerValue.timestamp,
        'updatedAtLocal': DateTime.now().toIso8601String(),
      };

      // Only update image if it was changed
      if (_imageChanged && _bookImageBase64 != null) {
        updatedData['imageUrl'] = _bookImageBase64!;
      }

      await bookRef.update(updatedData);

      // Close loading
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Book updated successfully!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );

        // Go back with result
        Navigator.of(context).pop(true);
      }
      
    } catch (e) {
      // Close loading if open
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating book: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStepData = _steps[_currentStep];
    final fields = currentStepData['fields'] as List<FormFieldConfig>;

    // Get screen size and define responsive breakpoints
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    final isSmallMobile = width < 360;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    
    // Responsive sizing variables
    final horizontalPadding = isSmallMobile ? 16.0 : (isMobile ? 18.0 : (isTablet ? 24.0 : 32.0));
    final spacing = isSmallMobile ? 16.0 : (isMobile ? 20.0 : (isTablet ? 24.0 : 28.0));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              _buildHeader(isSmallMobile, isMobile, isTablet, horizontalPadding),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      children: [
                        _buildFormCard(currentStepData, fields, isSmallMobile, isMobile, isTablet),
                        SizedBox(height: spacing),
                        _buildStepIndicators(isSmallMobile, isMobile),
                        SizedBox(height: spacing),
                        _buildActionButton(isSmallMobile, isMobile, isTablet),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallMobile, bool isMobile, bool isTablet, double horizontalPadding) {
    final titleFontSize = isSmallMobile ? 16.0 : (isMobile ? 17.0 : (isTablet ? 18.0 : 20.0));
    final iconSize = isSmallMobile ? 18.0 : (isMobile ? 19.0 : 20.0);
    final iconPadding = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    final verticalPadding = isSmallMobile ? 14.0 : (isMobile ? 15.0 : 16.0);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _previousStep,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Text(
              'Edit Book Details',
              style: GoogleFonts.poppins(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(Map<String, dynamic> stepData, List<FormFieldConfig> fields, bool isSmallMobile, bool isMobile, bool isTablet) {
    final cardPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : (isTablet ? 24.0 : 28.0));
    final titleFontSize = isSmallMobile ? 14.0 : (isMobile ? 15.0 : (isTablet ? 16.0 : 18.0));
    final subtitleFontSize = isSmallMobile ? 12.0 : (isMobile ? 12.5 : 13.0);
    final spacing = isSmallMobile ? 16.0 : (isMobile ? 18.0 : (isTablet ? 20.0 : 24.0));
    final fieldSpacing = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);
    
    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stepData['subtitle'] != null) ...[
            Text(
              stepData['title'],
              style: GoogleFonts.poppins(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
            SizedBox(height: spacing * 0.33),
            Text(
              stepData['subtitle'],
              style: GoogleFonts.poppins(
                fontSize: subtitleFontSize,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: spacing),
          ],
          // Image Upload Section (only on first step)
          if (_currentStep == 0) ...[
            _buildImageUploadSection(isSmallMobile, isMobile, isTablet),
            SizedBox(height: fieldSpacing),
          ],
          ...List.generate(
            fields.length,
            (index) => Column(
              children: [
                _buildDynamicTextField(fields[index], isSmallMobile, isMobile),
                if (index < fields.length - 1) SizedBox(height: fieldSpacing),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicTextField(FormFieldConfig config, bool isSmallMobile, bool isMobile) {
    final labelFontSize = isSmallMobile ? 13.0 : (isMobile ? 13.5 : 14.0);
    final hintFontSize = isSmallMobile ? 13.0 : (isMobile ? 13.5 : 14.0);
    final iconSize = isSmallMobile ? 18.0 : (isMobile ? 19.0 : 20.0);
    final labelSpacing = isSmallMobile ? 6.0 : (isMobile ? 7.0 : 8.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              config.label,
              style: GoogleFonts.poppins(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF374151),
              ),
            ),
            if (config.required)
              Text(
                ' *',
                style: GoogleFonts.poppins(
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFEF4444),
                ),
              ),
          ],
        ),
        SizedBox(height: labelSpacing),
        if (config.isDropdown && config.dropdownOptions != null)
          DropdownButtonFormField<String>(
            value: _formData[config.key],
            decoration: InputDecoration(
              prefixIcon: Icon(config.icon, color: const Color(0xFF6B7280), size: iconSize),
              hintText: 'Select ${config.label}',
              hintStyle: GoogleFonts.poppins(
                color: const Color(0xFFD1D5DB),
                fontSize: hintFontSize,
              ),
            ),
            items: config.dropdownOptions!.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: GoogleFonts.poppins(fontSize: hintFontSize),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _formData[config.key] = newValue;
                if (_controllers[config.key] != null) {
                  _controllers[config.key]!.text = newValue ?? '';
                }
              });
            },
            validator: config.validator ??
                (value) {
                  if (config.required && (value == null || value.isEmpty)) {
                    return 'Please select ${config.label}';
                  }
                  return null;
                },
          )
        else if (config.isDatePicker)
          TextFormField(
            controller: _controllers[config.key],
            readOnly: true,
            keyboardType: config.keyboardType,
            decoration: InputDecoration(
              prefixIcon: Icon(config.icon, color: const Color(0xFF6B7280), size: iconSize),
              suffixIcon: Icon(Icons.calendar_today, color: Color(0xFF6B7280), size: iconSize - 2),
              hintText: 'mm/dd/yyyy',
              hintStyle: GoogleFonts.poppins(
                color: const Color(0xFFD1D5DB),
                fontSize: hintFontSize,
              ),
            ),
            onTap: () => _selectDate(context, config.key),
            validator: config.validator ??
                (value) {
                  if (config.required && (value == null || value.isEmpty)) {
                    return 'Please enter ${config.label}';
                  }
                  return null;
                },
          )
        else
          TextFormField(
            controller: _controllers[config.key],
            maxLines: config.maxLines,
            keyboardType: config.keyboardType,
            decoration: InputDecoration(
              prefixIcon: Icon(config.icon, color: const Color(0xFF6B7280), size: iconSize),
              prefixText: config.prefix,
              hintText: 'Enter ${config.label}',
              hintStyle: GoogleFonts.poppins(
                color: const Color(0xFFD1D5DB),
                fontSize: hintFontSize,
              ),
            ),
            validator: config.validator ??
                (value) {
                  if (config.required && (value == null || value.isEmpty)) {
                    return 'Please enter ${config.label}';
                  }
                  return null;
                },
          ),
      ],
    );
  }

  Widget _buildImageUploadSection(bool isSmallMobile, bool isMobile, bool isTablet) {
    final labelFontSize = isSmallMobile ? 13.0 : (isMobile ? 13.5 : 14.0);
    final imageHeight = isSmallMobile ? 160.0 : (isMobile ? 180.0 : (isTablet ? 200.0 : 220.0));
    final iconPadding = isSmallMobile ? 12.0 : (isMobile ? 14.0 : 16.0);
    final iconSize = isSmallMobile ? 40.0 : (isMobile ? 44.0 : 48.0);
    final primaryTextSize = isSmallMobile ? 13.0 : (isMobile ? 13.5 : 14.0);
    final secondaryTextSize = isSmallMobile ? 11.0 : (isMobile ? 11.5 : 12.0);
    final buttonIconSize = isSmallMobile ? 16.0 : (isMobile ? 17.0 : 18.0);
    final buttonTextSize = isSmallMobile ? 11.0 : (isMobile ? 11.5 : 12.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Book Cover Image',
          style: GoogleFonts.poppins(
            fontSize: labelFontSize,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF374151),
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: imageHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: _bookImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _bookImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : _bookImageBase64 != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(_bookImageBase64!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImagePlaceholder(iconPadding, iconSize, primaryTextSize, secondaryTextSize);
                          },
                        ),
                      )
                    : _buildImagePlaceholder(iconPadding, iconSize, primaryTextSize, secondaryTextSize),
          ),
        ),
        if (_bookImage != null || _bookImageBase64 != null) ...[
          SizedBox(height: isMobile ? 6 : 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.edit, size: buttonIconSize),
                label: Text(
                  'Change Image',
                  style: GoogleFonts.poppins(fontSize: buttonTextSize),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _bookImage = null;
                    _bookImageBase64 = null;
                    _imageChanged = true;
                  });
                },
                icon: Icon(Icons.delete_outline, size: buttonIconSize),
                label: Text(
                  'Remove Image',
                  style: GoogleFonts.poppins(fontSize: buttonTextSize),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildImagePlaceholder(double iconPadding, double iconSize, double primaryTextSize, double secondaryTextSize) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(iconPadding),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add_photo_alternate_rounded,
            size: iconSize,
            color: AppColors.secondary,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Tap to upload book cover',
          style: GoogleFonts.poppins(
            fontSize: primaryTextSize,
            color: const Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'JPG, PNG (Max 5MB)',
          style: GoogleFonts.poppins(
            fontSize: secondaryTextSize,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        final bytes = await imageFile.readAsBytes();
        
        // Check file size (5MB limit)
        if (bytes.length > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image size should be less than 5MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _bookImage = imageFile;
          _bookImageBase64 = base64Encode(bytes);
          _imageChanged = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, String fieldKey) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.secondary,
              onPrimary: Colors.white,
              onSurface: AppColors.secondary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final formattedDate = 
          '${pickedDate.month.toString().padLeft(2, '0')}/'
          '${pickedDate.day.toString().padLeft(2, '0')}/'
          '${pickedDate.year}';
      
      setState(() {
        _controllers[fieldKey]!.text = formattedDate;
        _formData[fieldKey] = formattedDate;
      });
    }
  }

  Widget _buildStepIndicators(bool isSmallMobile, bool isMobile) {
    final lineWidth = isSmallMobile ? 30.0 : (isMobile ? 35.0 : 40.0);
    final lineMargin = isSmallMobile ? 6.0 : (isMobile ? 7.0 : 8.0);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _steps.length * 2 - 1,
        (index) {
          if (index.isOdd) {
            final lineIndex = index ~/ 2;
            return Container(
              width: lineWidth,
              height: 2,
              margin: EdgeInsets.symmetric(horizontal: lineMargin),
              color: _currentStep > lineIndex
                  ? AppColors.secondary
                  : const Color(0xFFE5E7EB),
            );
          } else {
            final stepIndex = index ~/ 2;
            return _buildStepIndicator(
              stepIndex,
              _steps[stepIndex]['title'],
              isSmallMobile,
              isMobile,
            );
          }
        },
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isSmallMobile, bool isMobile) {
    final isActive = _currentStep >= step;
    final circleSize = isSmallMobile ? 36.0 : (isMobile ? 38.0 : 40.0);
    final iconSize = isSmallMobile ? 18.0 : (isMobile ? 19.0 : 20.0);
    final numberFontSize = isSmallMobile ? 14.0 : (isMobile ? 15.0 : 16.0);
    final labelFontSize = isSmallMobile ? 11.0 : (isMobile ? 11.5 : 12.0);
    final labelSpacing = isSmallMobile ? 6.0 : (isMobile ? 7.0 : 8.0);
    
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: isActive ? AppColors.secondary : Colors.white,
            border: Border.all(
              color: isActive ? AppColors.secondary : const Color(0xFFE5E7EB),
              width: 2,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isActive && step < _currentStep
                ? Icon(Icons.check, color: Colors.white, size: iconSize)
                : Text(
                    '${step + 1}',
                    style: GoogleFonts.poppins(
                      color: isActive ? Colors.white : const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w600,
                      fontSize: numberFontSize,
                    ),
                  ),
          ),
        ),
        SizedBox(height: labelSpacing),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: labelFontSize,
            color: isActive ? AppColors.secondary : const Color(0xFF9CA3AF),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(bool isSmallMobile, bool isMobile, bool isTablet) {
    final buttonHeight = isSmallMobile ? 48.0 : (isMobile ? 50.0 : (isTablet ? 52.0 : 54.0));
    final buttonFontSize = isSmallMobile ? 14.0 : (isMobile ? 15.0 : (isTablet ? 16.0 : 17.0));
    final buttonRadius = isSmallMobile ? 10.0 : (isMobile ? 11.0 : 12.0);
    
    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: _nextStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
        child: Text(
          _currentStep == _steps.length - 1 ? 'Update Book' : 'Next',
          style: GoogleFonts.poppins(
            fontSize: buttonFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
