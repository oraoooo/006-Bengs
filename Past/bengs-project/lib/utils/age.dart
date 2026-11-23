/// Age in whole years on [now], accounting for whether the birthday has
/// happened yet this year — split out because BR-01/BR-02's age gates
/// (13/18) need to be exactly right, not "close enough".
int calculateAge(DateTime dateOfBirth, DateTime now) {
  var age = now.year - dateOfBirth.year;
  if (now.month < dateOfBirth.month ||
      (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
    age--;
  }
  return age;
}
