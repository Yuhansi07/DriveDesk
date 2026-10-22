import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  const ApiException(this.message, this.status);
  @override String toString() => message;
}
class DriveApi {
  static const base = String.fromEnvironment('API_BASE_URL',defaultValue:'http://127.0.0.1:3000');
  static const _storage=FlutterSecureStorage();
  String? token;
  Map<String,dynamic>? currentUser;
  Future<bool> restore() async {
    token=await _storage.read(key:'dd_token');
    if(token==null)return false;
    try{final r=await map('/api/auth/me');currentUser=Map<String,dynamic>.from(r['user']);return true;}
    catch(_){token=null;currentUser=null;await _storage.delete(key:'dd_token');return false;}
  }
  Future<dynamic> request(String method, String path, [Map<String,dynamic>? data]) async {
    final uri=Uri.parse('$base$path');
    final headers=<String,String>{'Content-Type':'application/json'};
    if(token!=null)headers['Authorization']='Bearer $token';
    late http.Response response;
    {
      try{
        switch(method){
          case 'GET':response=await http.get(uri,headers:headers);break;
          case 'POST':response=await http.post(uri,headers:headers,body:jsonEncode(data??{}));break;
          case 'PATCH':response=await http.patch(uri,headers:headers,body:jsonEncode(data??{}));break;
          case 'PUT':response=await http.put(uri,headers:headers,body:jsonEncode(data??{}));break;
          case 'DELETE':response=await http.delete(uri,headers:headers);break;
          default:throw Exception('Unsupported method $method');
        }
      }catch(e){if(e is ApiException)rethrow;throw ApiException('Cannot connect to $base. Is Node.js running? ($e)',0);}
    }
    dynamic decoded;
    try{decoded=jsonDecode(response.body);}catch(_){throw ApiException('Invalid server response (${response.statusCode}).',response.statusCode);}
    if(response.statusCode>=400)throw ApiException(decoded is Map?decoded['error']?.toString()??'Request failed':'Request failed',response.statusCode);
    return decoded;
  }
  Future<Map<String,dynamic>> login(String email,String password)async{
    final r=Map<String,dynamic>.from(await request('POST','/api/auth/login',{'email':email,'password':password}));
    token=r['token'] as String;
    currentUser=Map<String,dynamic>.from(r['user']);
    await _storage.write(key:'dd_token',value:token);
    return r;
  }
  Future<void> logout()async{try{await request('POST','/api/auth/logout',{});}catch(_){}token=null;currentUser=null;await _storage.delete(key:'dd_token');}
  Future<List<dynamic>> list(String path)async=>List<dynamic>.from(await request('GET',path));
  Future<Map<String,dynamic>> map(String path)async=>Map<String,dynamic>.from(await request('GET',path));
  Future<Map<String,dynamic>> post(String path,Map<String,dynamic> body)async=>Map<String,dynamic>.from(await request('POST',path,body));
  Future<Map<String,dynamic>> patch(String path,Map<String,dynamic> body)async=>Map<String,dynamic>.from(await request('PATCH',path,body));
  Future<Map<String,dynamic>> put(String path,Map<String,dynamic> body)async=>Map<String,dynamic>.from(await request('PUT',path,body));
  Future<void> delete(String path)async{await request('DELETE',path);}
}
