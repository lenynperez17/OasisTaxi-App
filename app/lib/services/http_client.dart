import 'dart:convert';
import 'package:dio/dio.dart';
import 'network_client.dart';
import '../utils/app_logger.dart';

/// HTTP Client wrapper that enforces SSL pinning via NetworkClient
/// All HTTP requests should go through this client to ensure certificate pinning
class HttpClient {
  static final HttpClient _instance = HttpClient._internal();
  factory HttpClient() => _instance;
  HttpClient._internal();

  final NetworkClient _networkClient = NetworkClient();

  /// Initialize the HTTP client (delegates to NetworkClient)
  Future<void> initialize() async {
    await _networkClient.initialize();
  }

  /// GET request with SSL pinning
  Future<HttpResponse> get(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _networkClient.get(
        url,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );

      return HttpResponse(
        statusCode: response.statusCode ?? 0,
        body: response.data is String ? response.data : json.encode(response.data),
        headers: _convertHeaders(response.headers),
        data: response.data,
      );
    } on DioException catch (e) {
      AppLogger.error('HTTP GET failed: $url', e);
      throw _convertDioException(e);
    }
  }

  /// POST request with SSL pinning
  Future<HttpResponse> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      // Convert body to appropriate format
      dynamic requestBody;
      if (body is Map || body is List) {
        requestBody = body;
      } else if (body is String) {
        // Try to parse as JSON, otherwise send as string
        try {
          requestBody = json.decode(body);
        } catch (_) {
          requestBody = body;
        }
      } else {
        requestBody = body;
      }

      final response = await _networkClient.post(
        url,
        data: requestBody,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );

      return HttpResponse(
        statusCode: response.statusCode ?? 0,
        body: response.data is String ? response.data : json.encode(response.data),
        headers: _convertHeaders(response.headers),
        data: response.data,
      );
    } on DioException catch (e) {
      AppLogger.error('HTTP POST failed: $url', e);
      throw _convertDioException(e);
    }
  }

  /// PUT request with SSL pinning
  Future<HttpResponse> put(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _networkClient.put(
        url,
        data: body,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );

      return HttpResponse(
        statusCode: response.statusCode ?? 0,
        body: response.data is String ? response.data : json.encode(response.data),
        headers: _convertHeaders(response.headers),
        data: response.data,
      );
    } on DioException catch (e) {
      AppLogger.error('HTTP PUT failed: $url', e);
      throw _convertDioException(e);
    }
  }

  /// DELETE request with SSL pinning
  Future<HttpResponse> delete(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _networkClient.delete(
        url,
        data: body,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );

      return HttpResponse(
        statusCode: response.statusCode ?? 0,
        body: response.data is String ? response.data : json.encode(response.data),
        headers: _convertHeaders(response.headers),
        data: response.data,
      );
    } on DioException catch (e) {
      AppLogger.error('HTTP DELETE failed: $url', e);
      throw _convertDioException(e);
    }
  }

  /// PATCH request with SSL pinning
  Future<HttpResponse> patch(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _networkClient.patch(
        url,
        data: body,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );

      return HttpResponse(
        statusCode: response.statusCode ?? 0,
        body: response.data is String ? response.data : json.encode(response.data),
        headers: _convertHeaders(response.headers),
        data: response.data,
      );
    } on DioException catch (e) {
      AppLogger.error('HTTP PATCH failed: $url', e);
      throw _convertDioException(e);
    }
  }

  /// Get the underlying Dio instance for advanced usage
  Dio get dio => _networkClient.dio;

  /// Convert Dio headers to Map<String, String>
  Map<String, String> _convertHeaders(Headers headers) {
    final Map<String, String> result = {};
    headers.forEach((name, values) {
      if (values.isNotEmpty) {
        result[name] = values.first;
      }
    });
    return result;
  }

  /// Convert DioException to HttpException for compatibility
  HttpException _convertDioException(DioException e) {
    String message = e.message ?? 'Network request failed';
    int? statusCode = e.response?.statusCode;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        message = 'Connection timeout';
        break;
      case DioExceptionType.receiveTimeout:
        message = 'Receive timeout';
        break;
      case DioExceptionType.badCertificate:
        message = 'Certificate verification failed (SSL pinning)';
        break;
      case DioExceptionType.connectionError:
        message = 'Connection error';
        break;
      case DioExceptionType.cancel:
        message = 'Request cancelled';
        break;
      case DioExceptionType.badResponse:
        message = 'Bad response: ${e.response?.statusCode}';
        statusCode = e.response?.statusCode;
        break;
      default:
        break;
    }

    return HttpException(
      message: message,
      statusCode: statusCode,
      response: e.response?.data,
    );
  }
}

/// HTTP Response wrapper for compatibility with existing code
class HttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final dynamic data; // Original data from Dio

  HttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    this.data,
  });

  /// Parse body as JSON
  dynamic get jsonBody {
    try {
      return json.decode(body);
    } catch (e) {
      return null;
    }
  }

  /// Check if response is successful
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// HTTP Exception for error handling
class HttpException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic response;

  HttpException({
    required this.message,
    this.statusCode,
    this.response,
  });

  @override
  String toString() => 'HttpException: $message (status: $statusCode)';
}