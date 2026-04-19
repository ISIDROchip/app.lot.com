/**
 * Calculates the age in full years from a given birth date to today.
 */
export function calculateAge(birthDate: Date): number {
  const today = new Date();
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age--;
  }
  return age;
}

/**
 * Returns true if the person born on birthDate is 18 years old or older today.
 */
export function isAdult(birthDate: Date): boolean {
  return calculateAge(birthDate) >= 18;
}
