import 'package:flutter/material.dart';

class StaticPageDialog extends StatelessWidget {
  final String title;
  final Widget content;

  const StaticPageDialog({
    super.key,
    required this.title,
    required this.content,
  });

  static void showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => StaticPageDialog(
        title: 'Privacy Policy',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Effective Date: November 2026 | Version 1.0.0',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            SizedBox(height: 16),
            Text(
              '1. Data Collection & Isolation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
            ),
            SizedBox(height: 6),
            Text(
              'PnumaDesk Manager operates as an administrative desktop console. All database credentials, secrets, Cloudflare R2 tokens, and SMS notification API keys configured within the system are stored locally in your dedicated Supabase clusters and are not transmitted to third-party tracking services.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
            ),
            SizedBox(height: 14),
            Text(
              '2. Role-Based Access Control',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
            ),
            SizedBox(height: 6),
            Text(
              'Administrative activities and security credentials are encrypted using SHA-256 and BCrypt protocols. Only authenticated Super Administrators and Administrators have visibility into tenant structures and sensitive endpoints.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
            ),
            SizedBox(height: 14),
            Text(
              '3. Audit Logging',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
            ),
            SizedBox(height: 6),
            Text(
              'System events including logins, maintenance triggers, app switches, and schema configurations are audited in the activity log table for compliance and internal security accountability.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  static void showTermsAndConditions(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => StaticPageDialog(
        title: 'Terms & Conditions',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Last Updated: November 2026 | Version 1.0.0',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            SizedBox(height: 16),
            Text(
              '1. Authorized Usage',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
            ),
            SizedBox(height: 6),
            Text(
              'PnumaDesk Manager is intended strictly for authorized administrators managing linked tenant systems (including Church Management and ministry enterprise instances). Unauthorized attempts to bypass role boundaries or tamper with cluster configurations are prohibited.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
            ),
            SizedBox(height: 14),
            Text(
              '2. Maintenance Mode Controls',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
            ),
            SizedBox(height: 6),
            Text(
              'Toggling maintenance mode or disabling system application services directly affects active mobile and desktop end-users. Administrators must exercise caution when performing live production modifications.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
            ),
            SizedBox(height: 14),
            Text(
              '3. Data Backups & Redundancy',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
            ),
            SizedBox(height: 6),
            Text(
              'Administrators are responsible for maintaining periodic exported backups using the built-in Profile Backup utility before conducting schema migrations or deleting project records.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  static void showContactUs(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => StaticPageDialog(
        title: 'Contact Support & Help Desk',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Developed by Krv Developers | Version 1.0.0',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Color(0xFF334155),
                child: Icon(Icons.business_outlined, color: Color(0xFF6366F1), size: 20),
              ),
              title: Text('Development Company', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('Krv Developers', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ),
            SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Color(0xFF334155),
                child: Icon(Icons.email_outlined, color: Color(0xFF38BDF8), size: 20),
              ),
              title: Text('Official Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('vishan.dias.official@gmail.com', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ),
            SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Color(0xFF334155),
                child: Icon(Icons.phone_outlined, color: Color(0xFF10B981), size: 20),
              ),
              title: Text('Hotline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('+94 78 376 4730', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFF334155)),
            content,
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
