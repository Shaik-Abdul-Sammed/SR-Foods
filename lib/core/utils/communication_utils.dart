import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class CommunicationUtils {
  static Future<void> launchPhone(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not initiate call to $phone'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> launchWhatsApp(BuildContext context, String phone, {String message = ''}) async {
    // Clean phone number (WhatsApp needs country code, but no +, spaces, or other characters)
    var cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // If the number doesn't start with a country code (like 91 for India), we could prepend one, 
    // but wa.me works best if we leave it to the user or if it's already complete.
    // If it's a standard 10-digit number without country code, we can prefix '91' for India as SR-Foods is likely in India.
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final Uri uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch WhatsApp. Please make sure the app is installed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
