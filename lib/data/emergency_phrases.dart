/// Preset phrases for Emergency mode.
///
/// NOTE: wording should be reviewed by Deaf Filipinos before release.
/// For example, "Deaf po ako" was chosen over "bingi" on purpose.
class EmergencyPhrase {
  const EmergencyPhrase({
    required this.icon,
    required this.en,
    required this.fil,
  });

  final String icon;
  final String en;
  final String fil;
}

const List<EmergencyPhrase> emergencyPhrases = [
  EmergencyPhrase(
    icon: '🆘',
    en: 'I need help.',
    fil: 'Kailangan ko po ng tulong.',
  ),
  EmergencyPhrase(
    icon: '🤟',
    en: 'I am Deaf. Please write or type.',
    fil: 'Deaf po ako. Pakisulat o i-type na lang po.',
  ),
  EmergencyPhrase(
    icon: '🚑',
    en: 'Please call an ambulance.',
    fil: 'Pakitawag po ng ambulansya.',
  ),
  EmergencyPhrase(
    icon: '🚓',
    en: 'Please call the police.',
    fil: 'Pakitawag po ang pulis.',
  ),
  EmergencyPhrase(
    icon: '🔥',
    en: 'There is a fire!',
    fil: 'May sunog po!',
  ),
  EmergencyPhrase(
    icon: '🩺',
    en: 'I need a doctor.',
    fil: 'Kailangan ko po ng doktor.',
  ),
  EmergencyPhrase(
    icon: '📍',
    en: 'It hurts here.',
    fil: 'Masakit po dito.',
  ),
  EmergencyPhrase(
    icon: '🧭',
    en: 'I am lost.',
    fil: 'Naliligaw po ako.',
  ),
  EmergencyPhrase(
    icon: '🗣️',
    en: 'Please face me and speak slowly.',
    fil: 'Pakiharap po sa akin at magsalita nang dahan-dahan.',
  ),
];
