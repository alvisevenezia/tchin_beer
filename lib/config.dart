const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

/// Link shared when inviting friends. Points at the reserved brand domain so
/// the shared URL stays stable even once the store listings go live (the domain
/// can redirect to the right place). Single source of truth — change here only.
const inviteUrl = 'https://tchin.beer';
