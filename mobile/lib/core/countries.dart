/// Countries offered at registration. Full names, not ISO codes, matching how
/// the API stores `users.country`.
const registrationCountries = [
  'Nigeria',
  'Kenya',
  'South Africa',
  'Rwanda',
  'Ghana',
  'Uganda',
  'Tanzania',
  'Other',
];

/// Countries a counterfeit report can be filed for: exactly those with a
/// medicines regulator in the `health_authorities` table (server/src/db/seed.ts),
/// since the report alert email is routed by this value.
const reportCountries = ['Nigeria', 'Kenya', 'South Africa', 'Rwanda', 'Ghana'];
