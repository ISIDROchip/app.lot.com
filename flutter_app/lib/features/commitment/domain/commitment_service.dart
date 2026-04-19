import 'package:dio/dio.dart';
import '../data/commitment_dto.dart';
import '../data/commitment_repository.dart';

class CommitmentService {
  final CommitmentRepository _repository;

  CommitmentService({CommitmentRepository? repository})
      : _repository = repository ?? CommitmentRepository();

  Future<ContractStatusResponse> checkStatus() async {
    return _repository.getStatus();
  }

  /// Validates fields client-side, then submits the form.
  /// Returns null on success, or an error message string on failure.
  Future<Map<String, dynamic>> submitForm({
    required String firstName,
    required String lastName,
    required String address,
    required String cedula,
    required String phone,
    required String signatureBase64,
    required bool checkboxAccepted,
    String? photoBase64,
    double? latitude,
    double? longitude,
    String? locationAddress,
  }) async {
    final request = SignContractRequest(
      firstName: firstName,
      lastName: lastName,
      address: address,
      cedula: cedula,
      phone: phone,
      digitalSignature: signatureBase64,
      checkboxAcceptance: checkboxAccepted,
      photoBase64: photoBase64,
      latitude: latitude,
      longitude: longitude,
      locationAddress: locationAddress,
    );

    try {
      return await _repository.sign(request);
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPaymentIntent() async {
    return _repository.createPaymentIntent();
  }

  Future<Pull10Response> requestPull10({String? lotteryId, String? paymentIntentId}) async {
    return _repository.pull10(lotteryId: lotteryId, paymentIntentId: paymentIntentId);
  }
}
