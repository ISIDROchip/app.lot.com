import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'bank_account_dto.dart';

class BankAccountRepository {
  final Dio _dio;
  BankAccountRepository() : _dio = dioInstance;

  Future<List<BankAccount>> getActiveBankAccounts() async {
    final res = await _dio.get('/bank-accounts');
    final data = res.data as Map<String, dynamic>;
    return (data['data'] as List)
        .map((e) => BankAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Admin Methods
  Future<List<BankAccount>> getAllBankAccounts() async {
    final res = await _dio.get('/admin/bank-accounts');
    final data = res.data as Map<String, dynamic>;
    return (data['data'] as List)
        .map((e) => BankAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BankAccount> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/admin/bank-accounts', data: data);
    return BankAccount.fromJson(res.data as Map<String, dynamic>);
  }

  Future<BankAccount> update(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/admin/bank-accounts/$id', data: data);
    return BankAccount.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/admin/bank-accounts/$id');
  }

  Future<void> setStatus(String id, bool isActive) async {
    await _dio.patch('/admin/bank-accounts/$id/status', data: {'is_active': isActive});
  }
}
