class BankAccount {
  final String id, bankName, accountNumber, accountType, accountHolder;
  final String? description;
  final bool isActive;

  BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountType,
    required this.accountHolder,
    this.description,
    required this.isActive,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        id: json['id'] as String,
        bankName: json['bank_name'] as String,
        accountNumber: json['account_number'] as String,
        accountType: json['account_type'] as String,
        accountHolder: json['account_holder'] as String,
        description: json['description'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
}
