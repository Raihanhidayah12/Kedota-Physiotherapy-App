import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'supabase_api_client.g.dart';

@RestApi()
abstract class SupabaseApiClient {
  factory SupabaseApiClient(Dio dio, {String? baseUrl}) = _SupabaseApiClient;

  @GET('/profiles')
  Future<List<Map<String, dynamic>>> getProfiles({
    @Query('select') String select = '*',
    @Header('apikey') required String apiKey,
    @Header('Authorization') required String authorization,
  });

  @POST('/profiles')
  Future<List<Map<String, dynamic>>> createProfile({
    @Header('apikey') required String apiKey,
    @Header('Authorization') required String authorization,
    @Body() required Map<String, dynamic> body,
  });

  @PATCH('/profiles')
  Future<List<Map<String, dynamic>>> updateProfile({
    @Query('id') required String id,
    @Header('apikey') required String apiKey,
    @Header('Authorization') required String authorization,
    @Body() required Map<String, dynamic> body,
  });
}
