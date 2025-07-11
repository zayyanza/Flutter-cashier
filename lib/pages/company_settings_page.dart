import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/settings_service.dart'; 

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({super.key});

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late CompanySettings _currentSettings;
  bool _isLoading = true;
  bool _isSaving = false;

  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _footnoteController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  XFile? _pickedLogoFile; 

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    _currentSettings = await CompanySettings.load();
    _nameController.text = _currentSettings.name;
    _addressController.text = _currentSettings.address;
    _phoneController.text = _currentSettings.phoneNumber;
    _footnoteController.text = _currentSettings.receiptFootnote;
    _pickedLogoFile = null; 
    setState(() => _isLoading = false);
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? selectedImage = await _picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 70,
        maxWidth: 300, 
      );
      if (selectedImage != null) {
        setState(() {
          _pickedLogoFile = selectedImage;
        });
      }
    } catch (e) {
      print("Error picking logo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking logo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeLogo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Logo'),
        content: const Text('Are you sure you want to remove the company logo?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove')),
        ],
      ),
    );

    if (confirm == true) {
       setState(() {
         _pickedLogoFile = null; 
         _currentSettings.logoPath = null;
       });
    }
  }


  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate() && !_isSaving) {
      setState(() => _isSaving = true);

      _currentSettings.name = _nameController.text.trim();
      _currentSettings.address = _addressController.text.trim();
      _currentSettings.phoneNumber = _phoneController.text.trim();
      _currentSettings.receiptFootnote = _footnoteController.text.trim();

      // Handle logo
      if (_pickedLogoFile != null) {
        bool success = await _currentSettings.setNewLogo(_pickedLogoFile!);
        if (!success && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Failed to save new logo.'), backgroundColor: Colors.red),
           );
           setState(() => _isSaving = false);
           return;
        }
      } else if (_currentSettings.logoPath == null && widgetInitialLogoPath != null) {
        // This case means user explicitly removed the logo (_currentSettings.logoPath became null)
      }


      await _currentSettings.save(); 

      setState(() {
         _isSaving = false;
         _pickedLogoFile = null; 
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company settings saved!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  // To track if the logo was present when the page loaded, for logic in _saveSettings if user removes it
  String? widgetInitialLogoPath;


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Company Information')), body: const Center(child: CircularProgressIndicator()));
    }
    // Store initial logo path once loaded
    if(widgetInitialLogoPath == null && _currentSettings.logoPath != null) {
      widgetInitialLogoPath = _currentSettings.logoPath;
    }


    Widget logoDisplay;
    if (_pickedLogoFile != null) {
       logoDisplay = Image.file(File(_pickedLogoFile!.path), height: 80, fit: BoxFit.contain);
    } else if (_currentSettings.logoPath != null && _currentSettings.logoPath!.isNotEmpty) {
       logoDisplay = Image.file(File(_currentSettings.logoPath!), height: 80, fit: BoxFit.contain);
    } else {
       logoDisplay = const Icon(Icons.business_outlined, size: 60, color: Colors.grey);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Information'),
        actions: [
          IconButton(
            icon: _isSaving ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,)) : const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(child: logoDisplay),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.image_search),
                    label: const Text('Change Logo'),
                    onPressed: _pickLogo,
                  ),
                  if (_pickedLogoFile != null || (_currentSettings.logoPath != null && _currentSettings.logoPath!.isNotEmpty))
                     TextButton.icon(
                       icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                       label: Text('Remove Logo', style: TextStyle(color: Colors.red[700])),
                       onPressed: _removeLogo,
                     ),
                ],
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Company name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _footnoteController,
                decoration: const InputDecoration(labelText: 'Receipt Footnote', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              SwitchListTile(
                title: const Text('Print Logo on Receipt'),
                value: _currentSettings.printLogoOnReceipt,
                onChanged: (bool value) {
                  setState(() {
                    _currentSettings.printLogoOnReceipt = value;
                  });
                },
                secondary: const Icon(Icons.image_outlined),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: _isSaving ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(strokeWidth: 2,)) : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save All Settings'),
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}