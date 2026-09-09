import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_language.dart';

const _teal = Color(0xFF008F87);
const _tealLight = Color(0xFFD4F5F3);
const _ink = Color(0xFF0E2C2F);
const _muted = Color(0xFF6F8D91);
const _background = Color(0xFFF0F7F7);

class _InfoScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final questions = [
      (t(context, 'faqQuestion1'), t(context, 'faqAnswer1')),
      (t(context, 'faqQuestion2'), t(context, 'faqAnswer2')),
      (t(context, 'faqQuestion3'), t(context, 'faqAnswer3')),
      (t(context, 'faqQuestion4'), t(context, 'faqAnswer4')),
    ];

    return _InfoScaffold(
      title: t(context, 'menuFaq'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(26, 16, 26, 32),
        children: [
          Text(
            t(context, 'faqIntro'),
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          _Panel(
            child: Column(
              children: [
                for (var i = 0; i < questions.length; i++) ...[
                  ExpansionTile(
                    tilePadding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    childrenPadding: const EdgeInsets.fromLTRB(68, 0, 20, 20),
                    shape: const RoundedRectangleBorder(),
                    collapsedShape: const RoundedRectangleBorder(),
                    backgroundColor: const Color(0xFFF8FCFC),
                    iconColor: _teal,
                    collapsedIconColor: _muted,
                    leading: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _tealLight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        '${i + 1}'.padLeft(2, '0'),
                        style: const TextStyle(
                          color: _teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      questions[i].$1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        height: 1.35,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          questions[i].$2,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 13,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (i < questions.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => _ArticleScreen(
    title: t(context, 'menuTerms'),
    sections: [
      (_lastUpdatedLabel(context), t(context, 'termsIntro')),
      (t(context, 'termsSection1'), t(context, 'termsBody1')),
      (t(context, 'termsSection2'), t(context, 'termsBody2')),
      (t(context, 'termsSection3'), t(context, 'termsBody3')),
      (t(context, 'termsSection4'), t(context, 'termsBody4')),
      (t(context, 'termsSection5'), t(context, 'termsBody5')),
      (t(context, 'termsSection6'), t(context, 'termsBody6')),
      (t(context, 'termsSection7'), t(context, 'termsBody7')),
      (t(context, 'termsSection8'), t(context, 'termsBody8')),
    ],
  );
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => _ArticleScreen(
    title: t(context, 'menuPrivacy'),
    sections: [
      (_lastUpdatedLabel(context), t(context, 'privacyIntro')),
      (t(context, 'privacySection1'), t(context, 'privacyBody1')),
      (t(context, 'privacySection2'), t(context, 'privacyBody2')),
      (t(context, 'privacySection3'), t(context, 'privacyBody3')),
      (t(context, 'privacySection4'), t(context, 'privacyBody4')),
      (t(context, 'privacySection5'), t(context, 'privacyBody5')),
      (t(context, 'privacySection6'), t(context, 'privacyBody6')),
      (t(context, 'privacySection7'), t(context, 'privacyBody7')),
    ],
  );
}

String _lastUpdatedLabel(BuildContext context) {
  final now = DateTime.now();
  final date =
      '${now.day.toString().padLeft(2, '0')}/'
      '${now.month.toString().padLeft(2, '0')}/'
      '${now.year}';
  return t(context, 'lastUpdated').replaceFirst('{date}', date);
}

class _ArticleScreen extends StatelessWidget {
  final String title;
  final List<(String, String)> sections;

  const _ArticleScreen({required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    final intro = sections.first;
    final articleSections = sections.skip(1).toList();

    return _InfoScaffold(
      title: title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(26, 16, 26, 32),
        children: [
          _Panel(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    intro.$1,
                    style: const TextStyle(
                      color: _teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    intro.$2,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            child: Column(
              children: [
                for (var i = 0; i < articleSections.length; i++) ...[
                  ExpansionTile(
                    tilePadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                    childrenPadding: const EdgeInsets.fromLTRB(68, 0, 20, 20),
                    shape: const RoundedRectangleBorder(),
                    collapsedShape: const RoundedRectangleBorder(),
                    backgroundColor: const Color(0xFFF8FCFC),
                    iconColor: _teal,
                    collapsedIconColor: _muted,
                    leading: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _tealLight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        '${i + 1}'.padLeft(2, '0'),
                        style: const TextStyle(
                          color: _teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      articleSections[i].$1,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          articleSections[i].$2,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 13,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (i < articleSections.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: t(context, 'menuCS'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(26, 16, 26, 32),
        children: [
          _ContentHeader(
            icon: Icons.support_agent_rounded,
            title: t(context, 'supportHeading'),
            description: t(context, 'supportDesc'),
          ),
          const SizedBox(height: 18),
          _Panel(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  _SupportOption(
                    icon: Icons.help_outline_rounded,
                    title: t(context, 'supportService'),
                    subtitle: t(context, 'supportServiceDesc'),
                  ),
                  const Divider(height: 28),
                  _SupportOption(
                    icon: Icons.folder_shared_outlined,
                    title: t(context, 'supportDataAccess'),
                    subtitle: t(context, 'supportDataAccessDesc'),
                  ),
                  const Divider(height: 28),
                  _SupportOption(
                    icon: Icons.privacy_tip_outlined,
                    title: t(context, 'supportPrivacy'),
                    subtitle: t(context, 'supportPrivacyDesc'),
                  ),
                  const Divider(height: 28),
                  _SupportOption(
                    icon: Icons.email_outlined,
                    title: t(context, 'supportEmail'),
                    subtitle: t(context, 'supportEmailPlaceholder'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'operatingHours'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(
                    label: t(context, 'weekdayHours'),
                    value: '08:00 - 20:00',
                  ),
                  _InfoRow(
                    label: t(context, 'saturdayHours'),
                    value: '08:00 - 18:00',
                  ),
                  _InfoRow(
                    label: t(context, 'sundayHours'),
                    value: t(context, 'closed'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'contact'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SupportOption(
                    icon: Icons.chat_rounded,
                    title: t(context, 'whatsapp'),
                    subtitle: '0816-4546-0939',
                    onTap: () => launchUrl(
                      Uri.parse('https://wa.me/6281645460939'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  const Divider(height: 28),
                  _SupportOption(
                    icon: Icons.email_outlined,
                    title: t(context, 'email'),
                    subtitle: 'info@kedota.com',
                    onTap: () => launchUrl(
                      Uri.parse('mailto:info@kedota.com'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SupportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _tealLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _teal),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: _muted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: _muted)),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
      ],
    ),
  );
}

class _ContentHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;

  const _ContentHeader({
    required this.icon,
    required this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _tealLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: _teal, size: 26),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 5),
              Text(
                description!,
                style: const TextStyle(
                  fontSize: 13,
                  color: _muted,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: _ink.withValues(alpha: 0.04),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}
