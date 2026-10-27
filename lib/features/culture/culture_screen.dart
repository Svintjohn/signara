import 'package:flutter/material.dart';

class _Topic {
  const _Topic(this.title, this.points);

  final String title;
  final List<String> points;
}

/// Awareness content. DRAFT written by hearing developers from general
/// knowledge. It MUST be reviewed, corrected and preferably rewritten by Deaf
/// Filipinos before release. Do not present it as authoritative.
const List<_Topic> _topics = [
  _Topic('Deaf and deaf', [
    'Capital-D "Deaf" usually means people who belong to the Deaf community '
        'and culture and use sign language. Lowercase "deaf" often describes '
        'hearing loss as a medical condition.',
    'When unsure, use the word the person uses for themselves.',
  ]),
  _Topic('Words to avoid', [
    '"Deaf-mute", "deaf and dumb", and the Filipino words "pipi" and "bingi" '
        'used as labels are offensive.',
    'Many Deaf people also dislike "hearing-impaired" because it describes '
        'them by what they lack. "Deaf" and "Hard of Hearing" are widely '
        'preferred.',
  ]),
  _Topic('Getting a Deaf person\'s attention', [
    'Wave in their line of sight, or tap their shoulder lightly.',
    'Flicking the lights on and off works in a room.',
    'Do not grab, pull, or shout.',
  ]),
  _Topic('Communicating well', [
    'Face the person and keep your face lit and visible. Do not cover your '
        'mouth.',
    'Use short, clear sentences. Write or type if it helps. Ask what works '
        'for them.',
    'With an interpreter present, look at and speak to the Deaf person, not '
        'the interpreter.',
    'Shouting does not help.',
  ]),
  _Topic('Sign languages are real languages', [
    'They have their own grammar. They are not signed versions of English or '
        'Filipino, and they are not just gestures or pantomime.',
    'Sign language is not universal. ASL (American Sign Language) is '
        'different from Filipino Sign Language (FSL).',
    'FSL is the natural sign language of the Filipino Deaf community. It has '
        'been influenced by ASL but has its own structure. (Check the law '
        'that recognizes FSL, and its exact name and date, before citing it.)',
    'This prototype teaches ASL first. FSL support is planned.',
  ]),
  _Topic('Common myths', [
    'Myth: all Deaf people can read lips. Lipreading is hard and unreliable.',
    'Myth: an app can replace an interpreter. It cannot. Apps like this miss '
        'facial expressions, grammar, and nuance.',
    'Myth: Deaf people are all the same. Experiences, languages and '
        'preferences differ a lot.',
  ]),
  _Topic('History and Deaf voices', [
    'Placeholder. This section should be written with Deaf Filipino '
        'creators and organizations, in their own words, with credit.',
  ]),
];

class CultureScreen extends StatelessWidget {
  const CultureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Deaf culture & etiquette',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'DRAFT written by hearing developers. It must be reviewed by '
            'Deaf Filipinos before release.',
          ),
        ),
        const SizedBox(height: 8),
        for (final t in _topics)
          Card(
            child: ExpansionTile(
              title: Text(t.title),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in t.points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('•  $p'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
