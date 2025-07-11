import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';

class CompanySettings {
  String name;
  String address;
  String phoneNumber;
  String? logoPath;
  bool printLogoOnReceipt;
  String receiptFootnote;
  bool isBuyingPriceRequired;
  bool isEmoneyActive;

  CompanySettings({
    this.name = 'My Awesome Store',
    this.address = '123 Main Street, Anytown',
    this.phoneNumber = '(555) 123-4567',
    this.logoPath,
    this.printLogoOnReceipt = true,
    this.receiptFootnote = 'Thank you for your business!',
    this.isBuyingPriceRequired = false,
    this.isEmoneyActive = true,
  });

  static Future<CompanySettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CompanySettings(
      name: prefs.getString(_Keys.companyName) ?? 'My Awesome Store',
      address: prefs.getString(_Keys.companyAddress) ?? '123 Main Street, Anytown',
      phoneNumber: prefs.getString(_Keys.companyPhoneNumber) ?? '(555) 123-4567',
      logoPath: prefs.getString(_Keys.companyLogoPath),
      printLogoOnReceipt: prefs.getBool(_Keys.printLogoOnReceipt) ?? true,
      receiptFootnote: prefs.getString(_Keys.receiptFootnote) ?? 'Thank you for your business!',
      isBuyingPriceRequired: prefs.getBool(_Keys.isBuyingPriceRequired) ?? false,
      isEmoneyActive: prefs.getBool(_Keys.isEmoneyActive) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_Keys.companyName, name);
    await prefs.setString(_Keys.companyAddress, address);
    await prefs.setString(_Keys.companyPhoneNumber, phoneNumber);
    if (logoPath != null) {
      await prefs.setString(_Keys.companyLogoPath, logoPath!);
    } else {
      await prefs.remove(_Keys.companyLogoPath);
    }
    await prefs.setBool(_Keys.printLogoOnReceipt, printLogoOnReceipt);
    await prefs.setString(_Keys.receiptFootnote, receiptFootnote);
    await prefs.setBool(_Keys.isBuyingPriceRequired, isBuyingPriceRequired);
    await prefs.setBool(_Keys.isEmoneyActive, isEmoneyActive);
  }

  Future<bool> setNewLogo(XFile imageFile) async {
    try {
      if (logoPath != null && logoPath!.isNotEmpty) {
        final File oldFile = File(logoPath!);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String fileName = 'company_logo${p.extension(imageFile.path)}';
      final String localFilePath = p.join(appDocDir.path, 'company_assets', fileName);
      final Directory imageDir = Directory(p.join(appDocDir.path, 'company_assets'));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      final File localImage = File(localFilePath);
      await localImage.writeAsBytes(await imageFile.readAsBytes());
      logoPath = localFilePath;
      return true;
    } catch (e) {
      print("Error saving new logo: $e");
      return false;
    }
  }

  Future<void> removeLogo() async {
    if (logoPath != null && logoPath!.isNotEmpty) {
      try {
        final File oldFile = File(logoPath!);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (e) {
        print("Error deleting logo file $logoPath: $e");
      }
    }
    logoPath = null;
  }
}

class _Keys {
  static const String companyName = 'companyName';
  static const String companyAddress = 'companyAddress';
  static const String companyPhoneNumber = 'companyPhoneNumber';
  static const String companyLogoPath = 'companyLogoPath';
  static const String printLogoOnReceipt = 'printLogoOnReceipt';
  static const String receiptFootnote = 'receiptFootnote';
  static const String isBuyingPriceRequired = 'isBuyingPriceRequired';
  static const String isEmoneyActive = 'isEmoneyActive';
}
