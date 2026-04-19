class ContractFieldDef {
  final String name;
  final String label;
  final String type;
  final bool required;

  const ContractFieldDef({
    required this.name,
    required this.label,
    required this.type,
    required this.required,
  });

  factory ContractFieldDef.fromJson(Map<String, dynamic> json) =>
      ContractFieldDef(
        name: json['name'] as String,
        label: json['label'] as String,
        type: json['type'] as String,
        required: json['required'] as bool,
      );
}

class ContractClause {
  final String id;
  final String version;
  final String text;

  const ContractClause(
      {required this.id, required this.version, required this.text});

  factory ContractClause.fromJson(Map<String, dynamic> json) => ContractClause(
        id: json['id'] as String,
        version: json['version'] as String,
        text: json['text'] as String,
      );
}

class ContractTemplate {
  final String contractVersion;
  final List<ContractFieldDef> fields;
  final List<ContractClause> clauses;

  const ContractTemplate({
    required this.contractVersion,
    required this.fields,
    required this.clauses,
  });

  factory ContractTemplate.fromJson(Map<String, dynamic> json) =>
      ContractTemplate(
        contractVersion: json['contract_version'] as String,
        fields: (json['fields'] as List<dynamic>)
            .map((e) => ContractFieldDef.fromJson(e as Map<String, dynamic>))
            .toList(),
        clauses: (json['clauses'] as List<dynamic>)
            .map((e) => ContractClause.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SignContractRequest {
  final String firstName;
  final String lastName;
  final String address;
  final String cedula;
  final String phone;
  final String digitalSignature;
  final bool checkboxAcceptance;
  final String? photoBase64; // foto del firmante (PNG Base64)
  final double? latitude; // coordenadas GPS
  final double? longitude;
  final String? locationAddress; // dirección legible

  const SignContractRequest({
    required this.firstName,
    required this.lastName,
    required this.address,
    required this.cedula,
    required this.phone,
    required this.digitalSignature,
    required this.checkboxAcceptance,
    this.photoBase64,
    this.latitude,
    this.longitude,
    this.locationAddress,
  });

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'address': address,
        'cedula': cedula,
        'phone': phone,
        'digital_signature': digitalSignature,
        'checkbox_acceptance': checkboxAcceptance,
        if (photoBase64 != null) 'photo_data': photoBase64,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (locationAddress != null) 'location_address': locationAddress,
      };
}

class ContractStatusResponse {
  final String status;
  final bool canPull;
  final String? contractId;
  final String? signedAt;
  final String? contractVersion;

  const ContractStatusResponse({
    required this.status,
    required this.canPull,
    this.contractId,
    this.signedAt,
    this.contractVersion,
  });

  factory ContractStatusResponse.fromJson(Map<String, dynamic> json) =>
      ContractStatusResponse(
        status: json['status'] as String,
        canPull: json['can_pull'] as bool,
        contractId: json['contract_id'] as String?,
        signedAt: json['signed_at'] as String?,
        contractVersion: json['contract_version'] as String?,
      );
}

class Pull10Response {
  final List<List<int>> combinations;
  final String? lotteryId;
  final String? contractId;
  final String timestamp;

  const Pull10Response({
    required this.combinations,
    this.lotteryId,
    this.contractId,
    required this.timestamp,
  });

  factory Pull10Response.fromJson(Map<String, dynamic> json) => Pull10Response(
        combinations: (json['combinations'] as List<dynamic>)
            .map((row) => (row as List<dynamic>).map((n) => n as int).toList())
            .toList(),
        lotteryId: json['lottery_id'] as String?,
        contractId: json['contract_id'] as String?,
        timestamp: json['timestamp'] as String,
      );
}
