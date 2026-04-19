import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'commitment_dto.dart';

class CommitmentRepository {
  final Dio _dio;

  CommitmentRepository({Dio? dio}) : _dio = dio ?? dioInstance;

  Future<ContractTemplate> getTemplate() async {
    final response = await _dio.get('/commitment/form');
    return ContractTemplate.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> sign(SignContractRequest request) async {
    final response = await _dio.post(
      '/commitment/sign',
      data: request.toJson(),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<ContractStatusResponse> getStatus() async {
    final response = await _dio.get('/commitment/status');
    return ContractStatusResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<String> getReport(String contractId) async {
    final response = await _dio.get('/commitment/report/$contractId');
    return (response.data as Map<String, dynamic>)['report'] as String;
  }

  Future<Map<String, dynamic>> createPaymentIntent() async {
    final response = await _dio.post('/lottery/create-payment-intent');
    return response.data as Map<String, dynamic>;
  }

  Future<Pull10Response> pull10({String? lotteryId, String? paymentIntentId}) async {
    final data = <String, dynamic>{};
    if (lotteryId != null) data['lottery_id'] = lotteryId;
    if (paymentIntentId != null) data['payment_intent_id'] = paymentIntentId;
    final response = await _dio.post('/lottery/pull-10', data: data);
    return Pull10Response.fromJson(response.data as Map<String, dynamic>);
  }
}
