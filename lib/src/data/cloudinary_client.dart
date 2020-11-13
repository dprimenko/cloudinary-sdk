import 'dart:typed_data';

import 'package:cloudinary_sdk/src/models/cloudinary_delivery_type.dart';
import 'package:cloudinary_sdk/src/models/cloudinary_resource_type.dart';
import 'package:cloudinary_sdk/src/models/cloudinary_response.dart';
import 'package:dio/dio.dart';
import 'cloudinary_api.dart';

class CloudinaryClient extends CloudinaryApi {
  String _cloudName;
  String _apiKey;
  String _apiSecret;

  CloudinaryClient(String apiKey, String apiSecret, String cloudName) : super(
    apiKey: apiKey,
    apiSecret: apiSecret
  ) {
    this._apiKey = apiKey;
    this._apiSecret = apiSecret;
    this._cloudName = cloudName;
  }

  Map<String, dynamic> _generateParams(Map<String, dynamic> params, {
    String fileName,
    String folder,
    CloudinaryResourceType resourceType,
    Map<String, dynamic> optParams
  }) {
    int timeStamp = new DateTime.now().millisecondsSinceEpoch;
    resourceType ??= CloudinaryResourceType.auto;

    if (_apiSecret == null || _apiKey == null)
      throw Exception("apiKey and apiSecret must not be null");

    Map<String, dynamic> fullParams = {};

    if (fileName != null) fullParams["public_id"] = fileName;
    if (folder != null) fullParams["folder"] = folder;

    //Setting the optParams... this would override the public_id and folder if specified by user.
    if (optParams != null) fullParams.addAll(optParams);
    fullParams["api_key"] = _apiKey;

    fullParams["timestamp"] = timeStamp;
    fullParams["signature"] =
        getSignature(secret: _apiSecret, timeStamp: timeStamp, params: fullParams);

    fullParams.addAll(params);
    return fullParams;
  }

  Future<CloudinaryResponse> _upload(Map<String, dynamic> params, {
    CloudinaryResourceType resourceType,
  }) async {
    FormData formData = new FormData.fromMap(params);

    Response response;
    int statusCode;
    CloudinaryResponse cloudinaryResponse;
    try {
      response = await post(_cloudName + "/${resourceType.name}/upload", data: formData);
      statusCode = response?.statusCode;
      cloudinaryResponse = CloudinaryResponse.fromJsonMap(response.data);
    } catch (error, stacktrace) {
      print("Exception occured: $error stackTrace: $stacktrace");
      if(error is DioError)
        statusCode = error.response?.statusCode;
      cloudinaryResponse = CloudinaryResponse.fromError("$error");
    }
    if(cloudinaryResponse != null)
      cloudinaryResponse..statusCode = statusCode;
    return cloudinaryResponse;
  }

  /// Uploads a file of [resourceType] with [fileName] to a [folder]
  /// in your specified [cloudName]
  ///
  /// [resourceType] defaults to [CloudinaryResourceType.auto]
  /// [fileName] is not mandatory, if not specified then a random name will be used
  /// [optParams] a Map of optional parameters as defined in https://cloudinary.com/documentation/image_upload_api_reference
  ///
  /// Response:
  /// Check all the atributes in the CloudinaryResponse to get the information you need... including secureUrl, publicId, etc.
  Future<CloudinaryResponse> uploadFile(String filePath,
      {String fileName,
      String folder,
      CloudinaryResourceType resourceType,
      Map<String, dynamic> optParams}) async {

    if (filePath == null) throw Exception("filePath must not be null");
    Map<String, dynamic> params = {};
    params["file"] = await MultipartFile.fromFile(filePath, filename: fileName);

    Map<String, dynamic> fullParams = _generateParams(params,
        fileName: fileName,
        folder: folder,
        resourceType: resourceType,
        optParams: optParams,
    );

    return _upload(fullParams, resourceType: resourceType);
  }

  Future<CloudinaryResponse> uploadByteData(ByteData byteData,
      {String fileName,
        String folder,
        CloudinaryResourceType resourceType,
        Map<String, dynamic> optParams}) async {

    if (byteData == null) throw Exception("byteData must not be null");
    Map<String, dynamic> params = {};
    params["file"] = await MultipartFile.fromBytes(byteData.buffer.asUint8List(), filename: fileName);

    Map<String, dynamic> fullParams = _generateParams(params,
      fileName: fileName,
      folder: folder,
      resourceType: resourceType,
      optParams: optParams,
    );

    return _upload(fullParams, resourceType: resourceType);
  }

  /// Deletes a file of [resourceType] with [publicId]
  /// from your specified [cloudName]
  ///
  /// [publicId] The identifier of the uploaded asset. Note: The public ID value for images and videos should not include a file extension. Include the file extension for raw files only.
  /// [resourceType] defaults to [CloudinaryResourceType.image]
  /// [invalidate] If true, invalidates CDN cached copies of the asset (and all its transformed versions). Default: false.
  /// [optParams] a Map of optional parameters as defined in https://cloudinary.com/documentation/image_upload_api_reference#destroy_method
  ///
  /// Response:
  /// Check response.isResultOk to know if the file was successfully deleted.
  Future<CloudinaryResponse> destroy(String publicId,
      {CloudinaryResourceType resourceType,
      bool invalidate,
      Map<String, dynamic> optParams}) async {
    int timeStamp = new DateTime.now().millisecondsSinceEpoch;
    resourceType ??= CloudinaryResourceType.image;

    if (_apiSecret == null || _apiKey == null)
      throw Exception("publicId, apiKey and apiSecret must not be null");

    Map<String, dynamic> params = new Map();

    if (optParams != null) params.addAll(optParams);
    if (invalidate != null) params["invalidate"] = invalidate;
    params["public_id"] = publicId;
    params["api_key"] = _apiKey;
    params["timestamp"] = timeStamp;
    params["signature"] =
        getSignature(secret: _apiSecret, timeStamp: timeStamp, params: params);

    FormData formData = new FormData.fromMap(params);

    Response response;
    CloudinaryResponse cloudinaryResponse;
    int statusCode;
    try {
      response = await post(_cloudName + "/${resourceType.name}/destroy", data: formData);
      statusCode = response?.statusCode;
      cloudinaryResponse = CloudinaryResponse.fromJsonMap(response.data);
    } catch (error, stacktrace) {
      print("Exception occured: $error stackTrace: $stacktrace");
      if(error is DioError)
        statusCode = error.response?.statusCode;
      cloudinaryResponse = CloudinaryResponse.fromError("$error");
    }
    if(cloudinaryResponse != null)
      cloudinaryResponse..statusCode = statusCode;
    return cloudinaryResponse;
  }

  /// Deletes a list of files of [resourceType] represented by
  /// it's [publicIds] from your specified [cloudName].
  /// Alternatively you can set a [prefix] to delete all files where the
  /// public_id starts with the prefix or you can also set [all] to delete all
  /// files of [resourceType]
  ///
  /// [publicIds] Delete all assets with the given public IDs (array of up to 100 public_ids).
  /// [prefix] Delete all assets, including derived assets, where the public ID starts with the given prefix (up to a maximum of 1000 original resources).
  /// [all] Delete all assets (of the relevant resource_type and type), including derived assets (up to a maximum of 1000 original resources).
  /// [resourceType] defaults to [CloudinaryResourceType.image]
  /// [deliveryType] defaults to [CloudinaryDeliveryType.upload]
  /// [invalidate] If true, invalidates CDN cached copies of the asset (and all its transformed versions). Default: false.
  /// [optParams] a Map of optional parameters as defined in https://cloudinary.com/documentation/admin_api#delete_resources
  ///
  /// Response:
  /// Check 'deleted' map inside CloudinaryResponse to know which files were deleted
  Future<CloudinaryResponse> deleteResources({
    List<String> publicIds,
    String prefix,
    bool all,
    CloudinaryResourceType resourceType,
    CloudinaryDeliveryType deliveryType,
    bool invalidate,
    Map<String, dynamic> optParams}) async {
    int timeStamp = new DateTime.now().millisecondsSinceEpoch;
    resourceType ??= CloudinaryResourceType.image;
    deliveryType ??= CloudinaryDeliveryType.upload;

    if (_apiSecret == null || _apiKey == null)
      throw Exception("publicId, apiKey and apiSecret must not be null");

    Map<String, dynamic> params = new Map();

    if (optParams != null) params.addAll(optParams);
    if (invalidate != null) params["invalidate"] = invalidate;
    if (publicIds != null) params["public_ids"] = publicIds; else
    if (prefix != null) params["prefix"] = prefix; else
    if (all != null) params["all"] = all;

    params["api_key"] = _apiKey;
    params["timestamp"] = timeStamp;
    params["signature"] =
        getSignature(secret: _apiSecret, timeStamp: timeStamp, params: params);

    FormData formData = new FormData.fromMap(params);

    Response response;
    CloudinaryResponse cloudinaryResponse;
    int statusCode;
    try {
      response = await delete(_cloudName + "/resources/${resourceType.name}/${deliveryType.name}", data: formData);
      statusCode = response?.statusCode;
      cloudinaryResponse = CloudinaryResponse.fromJsonMap(response.data);
    } catch (error, stacktrace) {
      print("Exception occured: $error stackTrace: $stacktrace");
      if(error is DioError)
        statusCode = error.response?.statusCode;
      cloudinaryResponse = CloudinaryResponse.fromError("$error");
    }
    if(cloudinaryResponse != null)
      cloudinaryResponse..statusCode = statusCode;
    return cloudinaryResponse;
  }
}
