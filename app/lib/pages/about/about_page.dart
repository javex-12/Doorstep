import 'package:doorstep_app/gen/strings.g.dart';
import 'package:doorstep_app/pages/debug/debug_page.dart';
import 'package:doorstep_app/widget/doorstep_logo.dart';
import 'package:doorstep_app/widget/responsive_list_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage();

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.aboutPage.title),
      ),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          const DoorstepLogo(withText: true, size: 48),
          const SizedBox(height: 8),
          Text(
            '© ${DateTime.now().year} cydercoder',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
          ),
          const SizedBox(height: 24),
          const Text(
            'Doorstep is an ultra-fast, local-first file transfer network. No clouds, no setup, no friction — your phone is now another folder on your computer.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, height: 1.5),
          ),
          const SizedBox(height: 28),
          const Text('Created by', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'cydercoder',
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () async {
                      await launchUrl(Uri.parse('https://cydercoder.vercel.app'), mode: LaunchMode.externalApplication);
                    },
                ),
                const TextSpan(text: '  ·  '),
                TextSpan(
                  text: '@javex-12',
                  style: TextStyle(color: primaryColor),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () async {
                      await launchUrl(Uri.parse('https://github.com/javex-12'), mode: LaunchMode.externalApplication);
                    },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Open Source & Collaboration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          const Text(
            'We are actively welcoming collaborators, contributors, and translators to help build the best local transfer experience.',
            style: TextStyle(fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              await launchUrl(Uri.parse('https://github.com/javex-12/Doorstep'), mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.code_rounded, size: 18),
            label: const Text('Contribute on GitHub'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.source_rounded),
                title: const Text('Source Code'),
                subtitle: const Text('github.com/javex-12/Doorstep'),
                onTap: () async {
                  await launchUrl(Uri.parse('https://github.com/javex-12/Doorstep'), mode: LaunchMode.externalApplication);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_rounded),
                title: const Text('License Notices'),
                subtitle: const Text('Apache License 2.0 & dependencies'),
                onTap: () async {
                  await context.push(() => const LicensePage());
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bug_report_rounded),
                title: const Text('Diagnostics & Logs'),
                onTap: () async {
                  await context.push(() => const DebugPage());
                },
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
