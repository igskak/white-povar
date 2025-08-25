// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'detected_ingredient.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DetectedIngredient _$DetectedIngredientFromJson(Map<String, dynamic> json) {
  return _DetectedIngredient.fromJson(json);
}

/// @nodoc
mixin _$DetectedIngredient {
  String get name => throw _privateConstructorUsedError;
  double get confidence => throw _privateConstructorUsedError;
  bool get isConfirmed => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  String get id => throw _privateConstructorUsedError;

  /// Serializes this DetectedIngredient to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DetectedIngredient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DetectedIngredientCopyWith<DetectedIngredient> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DetectedIngredientCopyWith<$Res> {
  factory $DetectedIngredientCopyWith(
          DetectedIngredient value, $Res Function(DetectedIngredient) then) =
      _$DetectedIngredientCopyWithImpl<$Res, DetectedIngredient>;
  @useResult
  $Res call(
      {String name,
      double confidence,
      bool isConfirmed,
      String? notes,
      String id});
}

/// @nodoc
class _$DetectedIngredientCopyWithImpl<$Res, $Val extends DetectedIngredient>
    implements $DetectedIngredientCopyWith<$Res> {
  _$DetectedIngredientCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DetectedIngredient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? confidence = null,
    Object? isConfirmed = null,
    Object? notes = freezed,
    Object? id = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double,
      isConfirmed: null == isConfirmed
          ? _value.isConfirmed
          : isConfirmed // ignore: cast_nullable_to_non_nullable
              as bool,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DetectedIngredientImplCopyWith<$Res>
    implements $DetectedIngredientCopyWith<$Res> {
  factory _$$DetectedIngredientImplCopyWith(_$DetectedIngredientImpl value,
          $Res Function(_$DetectedIngredientImpl) then) =
      __$$DetectedIngredientImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      double confidence,
      bool isConfirmed,
      String? notes,
      String id});
}

/// @nodoc
class __$$DetectedIngredientImplCopyWithImpl<$Res>
    extends _$DetectedIngredientCopyWithImpl<$Res, _$DetectedIngredientImpl>
    implements _$$DetectedIngredientImplCopyWith<$Res> {
  __$$DetectedIngredientImplCopyWithImpl(_$DetectedIngredientImpl _value,
      $Res Function(_$DetectedIngredientImpl) _then)
      : super(_value, _then);

  /// Create a copy of DetectedIngredient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? confidence = null,
    Object? isConfirmed = null,
    Object? notes = freezed,
    Object? id = null,
  }) {
    return _then(_$DetectedIngredientImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double,
      isConfirmed: null == isConfirmed
          ? _value.isConfirmed
          : isConfirmed // ignore: cast_nullable_to_non_nullable
              as bool,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DetectedIngredientImpl implements _DetectedIngredient {
  const _$DetectedIngredientImpl(
      {required this.name,
      this.confidence = 0.0,
      this.isConfirmed = true,
      this.notes,
      this.id = ''});

  factory _$DetectedIngredientImpl.fromJson(Map<String, dynamic> json) =>
      _$$DetectedIngredientImplFromJson(json);

  @override
  final String name;
  @override
  @JsonKey()
  final double confidence;
  @override
  @JsonKey()
  final bool isConfirmed;
  @override
  final String? notes;
  @override
  @JsonKey()
  final String id;

  @override
  String toString() {
    return 'DetectedIngredient(name: $name, confidence: $confidence, isConfirmed: $isConfirmed, notes: $notes, id: $id)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DetectedIngredientImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.isConfirmed, isConfirmed) ||
                other.isConfirmed == isConfirmed) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.id, id) || other.id == id));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, name, confidence, isConfirmed, notes, id);

  /// Create a copy of DetectedIngredient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DetectedIngredientImplCopyWith<_$DetectedIngredientImpl> get copyWith =>
      __$$DetectedIngredientImplCopyWithImpl<_$DetectedIngredientImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DetectedIngredientImplToJson(
      this,
    );
  }
}

abstract class _DetectedIngredient implements DetectedIngredient {
  const factory _DetectedIngredient(
      {required final String name,
      final double confidence,
      final bool isConfirmed,
      final String? notes,
      final String id}) = _$DetectedIngredientImpl;

  factory _DetectedIngredient.fromJson(Map<String, dynamic> json) =
      _$DetectedIngredientImpl.fromJson;

  @override
  String get name;
  @override
  double get confidence;
  @override
  bool get isConfirmed;
  @override
  String? get notes;
  @override
  String get id;

  /// Create a copy of DetectedIngredient
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DetectedIngredientImplCopyWith<_$DetectedIngredientImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PhotoSearchRequest _$PhotoSearchRequestFromJson(Map<String, dynamic> json) {
  return _PhotoSearchRequest.fromJson(json);
}

/// @nodoc
mixin _$PhotoSearchRequest {
  String get image => throw _privateConstructorUsedError;
  String? get chefId => throw _privateConstructorUsedError;
  int get maxResults => throw _privateConstructorUsedError;

  /// Serializes this PhotoSearchRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PhotoSearchRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PhotoSearchRequestCopyWith<PhotoSearchRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PhotoSearchRequestCopyWith<$Res> {
  factory $PhotoSearchRequestCopyWith(
          PhotoSearchRequest value, $Res Function(PhotoSearchRequest) then) =
      _$PhotoSearchRequestCopyWithImpl<$Res, PhotoSearchRequest>;
  @useResult
  $Res call({String image, String? chefId, int maxResults});
}

/// @nodoc
class _$PhotoSearchRequestCopyWithImpl<$Res, $Val extends PhotoSearchRequest>
    implements $PhotoSearchRequestCopyWith<$Res> {
  _$PhotoSearchRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PhotoSearchRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? image = null,
    Object? chefId = freezed,
    Object? maxResults = null,
  }) {
    return _then(_value.copyWith(
      image: null == image
          ? _value.image
          : image // ignore: cast_nullable_to_non_nullable
              as String,
      chefId: freezed == chefId
          ? _value.chefId
          : chefId // ignore: cast_nullable_to_non_nullable
              as String?,
      maxResults: null == maxResults
          ? _value.maxResults
          : maxResults // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PhotoSearchRequestImplCopyWith<$Res>
    implements $PhotoSearchRequestCopyWith<$Res> {
  factory _$$PhotoSearchRequestImplCopyWith(_$PhotoSearchRequestImpl value,
          $Res Function(_$PhotoSearchRequestImpl) then) =
      __$$PhotoSearchRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String image, String? chefId, int maxResults});
}

/// @nodoc
class __$$PhotoSearchRequestImplCopyWithImpl<$Res>
    extends _$PhotoSearchRequestCopyWithImpl<$Res, _$PhotoSearchRequestImpl>
    implements _$$PhotoSearchRequestImplCopyWith<$Res> {
  __$$PhotoSearchRequestImplCopyWithImpl(_$PhotoSearchRequestImpl _value,
      $Res Function(_$PhotoSearchRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of PhotoSearchRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? image = null,
    Object? chefId = freezed,
    Object? maxResults = null,
  }) {
    return _then(_$PhotoSearchRequestImpl(
      image: null == image
          ? _value.image
          : image // ignore: cast_nullable_to_non_nullable
              as String,
      chefId: freezed == chefId
          ? _value.chefId
          : chefId // ignore: cast_nullable_to_non_nullable
              as String?,
      maxResults: null == maxResults
          ? _value.maxResults
          : maxResults // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PhotoSearchRequestImpl implements _PhotoSearchRequest {
  const _$PhotoSearchRequestImpl(
      {required this.image, this.chefId, this.maxResults = 10});

  factory _$PhotoSearchRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$PhotoSearchRequestImplFromJson(json);

  @override
  final String image;
  @override
  final String? chefId;
  @override
  @JsonKey()
  final int maxResults;

  @override
  String toString() {
    return 'PhotoSearchRequest(image: $image, chefId: $chefId, maxResults: $maxResults)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PhotoSearchRequestImpl &&
            (identical(other.image, image) || other.image == image) &&
            (identical(other.chefId, chefId) || other.chefId == chefId) &&
            (identical(other.maxResults, maxResults) ||
                other.maxResults == maxResults));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, image, chefId, maxResults);

  /// Create a copy of PhotoSearchRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PhotoSearchRequestImplCopyWith<_$PhotoSearchRequestImpl> get copyWith =>
      __$$PhotoSearchRequestImplCopyWithImpl<_$PhotoSearchRequestImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PhotoSearchRequestImplToJson(
      this,
    );
  }
}

abstract class _PhotoSearchRequest implements PhotoSearchRequest {
  const factory _PhotoSearchRequest(
      {required final String image,
      final String? chefId,
      final int maxResults}) = _$PhotoSearchRequestImpl;

  factory _PhotoSearchRequest.fromJson(Map<String, dynamic> json) =
      _$PhotoSearchRequestImpl.fromJson;

  @override
  String get image;
  @override
  String? get chefId;
  @override
  int get maxResults;

  /// Create a copy of PhotoSearchRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PhotoSearchRequestImplCopyWith<_$PhotoSearchRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PhotoSearchResponse _$PhotoSearchResponseFromJson(Map<String, dynamic> json) {
  return _PhotoSearchResponse.fromJson(json);
}

/// @nodoc
mixin _$PhotoSearchResponse {
  List<String> get ingredients => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get suggestedRecipes =>
      throw _privateConstructorUsedError;
  double get confidenceScore => throw _privateConstructorUsedError;

  /// Serializes this PhotoSearchResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PhotoSearchResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PhotoSearchResponseCopyWith<PhotoSearchResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PhotoSearchResponseCopyWith<$Res> {
  factory $PhotoSearchResponseCopyWith(
          PhotoSearchResponse value, $Res Function(PhotoSearchResponse) then) =
      _$PhotoSearchResponseCopyWithImpl<$Res, PhotoSearchResponse>;
  @useResult
  $Res call(
      {List<String> ingredients,
      List<Map<String, dynamic>> suggestedRecipes,
      double confidenceScore});
}

/// @nodoc
class _$PhotoSearchResponseCopyWithImpl<$Res, $Val extends PhotoSearchResponse>
    implements $PhotoSearchResponseCopyWith<$Res> {
  _$PhotoSearchResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PhotoSearchResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ingredients = null,
    Object? suggestedRecipes = null,
    Object? confidenceScore = null,
  }) {
    return _then(_value.copyWith(
      ingredients: null == ingredients
          ? _value.ingredients
          : ingredients // ignore: cast_nullable_to_non_nullable
              as List<String>,
      suggestedRecipes: null == suggestedRecipes
          ? _value.suggestedRecipes
          : suggestedRecipes // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      confidenceScore: null == confidenceScore
          ? _value.confidenceScore
          : confidenceScore // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PhotoSearchResponseImplCopyWith<$Res>
    implements $PhotoSearchResponseCopyWith<$Res> {
  factory _$$PhotoSearchResponseImplCopyWith(_$PhotoSearchResponseImpl value,
          $Res Function(_$PhotoSearchResponseImpl) then) =
      __$$PhotoSearchResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<String> ingredients,
      List<Map<String, dynamic>> suggestedRecipes,
      double confidenceScore});
}

/// @nodoc
class __$$PhotoSearchResponseImplCopyWithImpl<$Res>
    extends _$PhotoSearchResponseCopyWithImpl<$Res, _$PhotoSearchResponseImpl>
    implements _$$PhotoSearchResponseImplCopyWith<$Res> {
  __$$PhotoSearchResponseImplCopyWithImpl(_$PhotoSearchResponseImpl _value,
      $Res Function(_$PhotoSearchResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of PhotoSearchResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ingredients = null,
    Object? suggestedRecipes = null,
    Object? confidenceScore = null,
  }) {
    return _then(_$PhotoSearchResponseImpl(
      ingredients: null == ingredients
          ? _value._ingredients
          : ingredients // ignore: cast_nullable_to_non_nullable
              as List<String>,
      suggestedRecipes: null == suggestedRecipes
          ? _value._suggestedRecipes
          : suggestedRecipes // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      confidenceScore: null == confidenceScore
          ? _value.confidenceScore
          : confidenceScore // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PhotoSearchResponseImpl implements _PhotoSearchResponse {
  const _$PhotoSearchResponseImpl(
      {final List<String> ingredients = const [],
      final List<Map<String, dynamic>> suggestedRecipes = const [],
      this.confidenceScore = 0.0})
      : _ingredients = ingredients,
        _suggestedRecipes = suggestedRecipes;

  factory _$PhotoSearchResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$PhotoSearchResponseImplFromJson(json);

  final List<String> _ingredients;
  @override
  @JsonKey()
  List<String> get ingredients {
    if (_ingredients is EqualUnmodifiableListView) return _ingredients;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ingredients);
  }

  final List<Map<String, dynamic>> _suggestedRecipes;
  @override
  @JsonKey()
  List<Map<String, dynamic>> get suggestedRecipes {
    if (_suggestedRecipes is EqualUnmodifiableListView)
      return _suggestedRecipes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_suggestedRecipes);
  }

  @override
  @JsonKey()
  final double confidenceScore;

  @override
  String toString() {
    return 'PhotoSearchResponse(ingredients: $ingredients, suggestedRecipes: $suggestedRecipes, confidenceScore: $confidenceScore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PhotoSearchResponseImpl &&
            const DeepCollectionEquality()
                .equals(other._ingredients, _ingredients) &&
            const DeepCollectionEquality()
                .equals(other._suggestedRecipes, _suggestedRecipes) &&
            (identical(other.confidenceScore, confidenceScore) ||
                other.confidenceScore == confidenceScore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_ingredients),
      const DeepCollectionEquality().hash(_suggestedRecipes),
      confidenceScore);

  /// Create a copy of PhotoSearchResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PhotoSearchResponseImplCopyWith<_$PhotoSearchResponseImpl> get copyWith =>
      __$$PhotoSearchResponseImplCopyWithImpl<_$PhotoSearchResponseImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PhotoSearchResponseImplToJson(
      this,
    );
  }
}

abstract class _PhotoSearchResponse implements PhotoSearchResponse {
  const factory _PhotoSearchResponse(
      {final List<String> ingredients,
      final List<Map<String, dynamic>> suggestedRecipes,
      final double confidenceScore}) = _$PhotoSearchResponseImpl;

  factory _PhotoSearchResponse.fromJson(Map<String, dynamic> json) =
      _$PhotoSearchResponseImpl.fromJson;

  @override
  List<String> get ingredients;
  @override
  List<Map<String, dynamic>> get suggestedRecipes;
  @override
  double get confidenceScore;

  /// Create a copy of PhotoSearchResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PhotoSearchResponseImplCopyWith<_$PhotoSearchResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CameraState {
  bool get isInitialized => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  bool get hasPermission => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  String? get capturedImagePath => throw _privateConstructorUsedError;

  /// Create a copy of CameraState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CameraStateCopyWith<CameraState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CameraStateCopyWith<$Res> {
  factory $CameraStateCopyWith(
          CameraState value, $Res Function(CameraState) then) =
      _$CameraStateCopyWithImpl<$Res, CameraState>;
  @useResult
  $Res call(
      {bool isInitialized,
      bool isLoading,
      bool hasPermission,
      String? error,
      String? capturedImagePath});
}

/// @nodoc
class _$CameraStateCopyWithImpl<$Res, $Val extends CameraState>
    implements $CameraStateCopyWith<$Res> {
  _$CameraStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CameraState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isInitialized = null,
    Object? isLoading = null,
    Object? hasPermission = null,
    Object? error = freezed,
    Object? capturedImagePath = freezed,
  }) {
    return _then(_value.copyWith(
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      hasPermission: null == hasPermission
          ? _value.hasPermission
          : hasPermission // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      capturedImagePath: freezed == capturedImagePath
          ? _value.capturedImagePath
          : capturedImagePath // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CameraStateImplCopyWith<$Res>
    implements $CameraStateCopyWith<$Res> {
  factory _$$CameraStateImplCopyWith(
          _$CameraStateImpl value, $Res Function(_$CameraStateImpl) then) =
      __$$CameraStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isInitialized,
      bool isLoading,
      bool hasPermission,
      String? error,
      String? capturedImagePath});
}

/// @nodoc
class __$$CameraStateImplCopyWithImpl<$Res>
    extends _$CameraStateCopyWithImpl<$Res, _$CameraStateImpl>
    implements _$$CameraStateImplCopyWith<$Res> {
  __$$CameraStateImplCopyWithImpl(
      _$CameraStateImpl _value, $Res Function(_$CameraStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of CameraState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isInitialized = null,
    Object? isLoading = null,
    Object? hasPermission = null,
    Object? error = freezed,
    Object? capturedImagePath = freezed,
  }) {
    return _then(_$CameraStateImpl(
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      hasPermission: null == hasPermission
          ? _value.hasPermission
          : hasPermission // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      capturedImagePath: freezed == capturedImagePath
          ? _value.capturedImagePath
          : capturedImagePath // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$CameraStateImpl implements _CameraState {
  const _$CameraStateImpl(
      {this.isInitialized = false,
      this.isLoading = false,
      this.hasPermission = false,
      this.error,
      this.capturedImagePath});

  @override
  @JsonKey()
  final bool isInitialized;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool hasPermission;
  @override
  final String? error;
  @override
  final String? capturedImagePath;

  @override
  String toString() {
    return 'CameraState(isInitialized: $isInitialized, isLoading: $isLoading, hasPermission: $hasPermission, error: $error, capturedImagePath: $capturedImagePath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CameraStateImpl &&
            (identical(other.isInitialized, isInitialized) ||
                other.isInitialized == isInitialized) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.hasPermission, hasPermission) ||
                other.hasPermission == hasPermission) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.capturedImagePath, capturedImagePath) ||
                other.capturedImagePath == capturedImagePath));
  }

  @override
  int get hashCode => Object.hash(runtimeType, isInitialized, isLoading,
      hasPermission, error, capturedImagePath);

  /// Create a copy of CameraState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CameraStateImplCopyWith<_$CameraStateImpl> get copyWith =>
      __$$CameraStateImplCopyWithImpl<_$CameraStateImpl>(this, _$identity);
}

abstract class _CameraState implements CameraState {
  const factory _CameraState(
      {final bool isInitialized,
      final bool isLoading,
      final bool hasPermission,
      final String? error,
      final String? capturedImagePath}) = _$CameraStateImpl;

  @override
  bool get isInitialized;
  @override
  bool get isLoading;
  @override
  bool get hasPermission;
  @override
  String? get error;
  @override
  String? get capturedImagePath;

  /// Create a copy of CameraState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CameraStateImplCopyWith<_$CameraStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PhotoSearchState {
  bool get isLoading => throw _privateConstructorUsedError;
  List<DetectedIngredient> get detectedIngredients =>
      throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get suggestedRecipes =>
      throw _privateConstructorUsedError;
  double get confidence => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of PhotoSearchState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PhotoSearchStateCopyWith<PhotoSearchState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PhotoSearchStateCopyWith<$Res> {
  factory $PhotoSearchStateCopyWith(
          PhotoSearchState value, $Res Function(PhotoSearchState) then) =
      _$PhotoSearchStateCopyWithImpl<$Res, PhotoSearchState>;
  @useResult
  $Res call(
      {bool isLoading,
      List<DetectedIngredient> detectedIngredients,
      List<Map<String, dynamic>> suggestedRecipes,
      double confidence,
      String? error});
}

/// @nodoc
class _$PhotoSearchStateCopyWithImpl<$Res, $Val extends PhotoSearchState>
    implements $PhotoSearchStateCopyWith<$Res> {
  _$PhotoSearchStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PhotoSearchState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLoading = null,
    Object? detectedIngredients = null,
    Object? suggestedRecipes = null,
    Object? confidence = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      detectedIngredients: null == detectedIngredients
          ? _value.detectedIngredients
          : detectedIngredients // ignore: cast_nullable_to_non_nullable
              as List<DetectedIngredient>,
      suggestedRecipes: null == suggestedRecipes
          ? _value.suggestedRecipes
          : suggestedRecipes // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PhotoSearchStateImplCopyWith<$Res>
    implements $PhotoSearchStateCopyWith<$Res> {
  factory _$$PhotoSearchStateImplCopyWith(_$PhotoSearchStateImpl value,
          $Res Function(_$PhotoSearchStateImpl) then) =
      __$$PhotoSearchStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isLoading,
      List<DetectedIngredient> detectedIngredients,
      List<Map<String, dynamic>> suggestedRecipes,
      double confidence,
      String? error});
}

/// @nodoc
class __$$PhotoSearchStateImplCopyWithImpl<$Res>
    extends _$PhotoSearchStateCopyWithImpl<$Res, _$PhotoSearchStateImpl>
    implements _$$PhotoSearchStateImplCopyWith<$Res> {
  __$$PhotoSearchStateImplCopyWithImpl(_$PhotoSearchStateImpl _value,
      $Res Function(_$PhotoSearchStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of PhotoSearchState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLoading = null,
    Object? detectedIngredients = null,
    Object? suggestedRecipes = null,
    Object? confidence = null,
    Object? error = freezed,
  }) {
    return _then(_$PhotoSearchStateImpl(
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      detectedIngredients: null == detectedIngredients
          ? _value._detectedIngredients
          : detectedIngredients // ignore: cast_nullable_to_non_nullable
              as List<DetectedIngredient>,
      suggestedRecipes: null == suggestedRecipes
          ? _value._suggestedRecipes
          : suggestedRecipes // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$PhotoSearchStateImpl implements _PhotoSearchState {
  const _$PhotoSearchStateImpl(
      {this.isLoading = false,
      final List<DetectedIngredient> detectedIngredients = const [],
      final List<Map<String, dynamic>> suggestedRecipes = const [],
      this.confidence = 0.0,
      this.error})
      : _detectedIngredients = detectedIngredients,
        _suggestedRecipes = suggestedRecipes;

  @override
  @JsonKey()
  final bool isLoading;
  final List<DetectedIngredient> _detectedIngredients;
  @override
  @JsonKey()
  List<DetectedIngredient> get detectedIngredients {
    if (_detectedIngredients is EqualUnmodifiableListView)
      return _detectedIngredients;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_detectedIngredients);
  }

  final List<Map<String, dynamic>> _suggestedRecipes;
  @override
  @JsonKey()
  List<Map<String, dynamic>> get suggestedRecipes {
    if (_suggestedRecipes is EqualUnmodifiableListView)
      return _suggestedRecipes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_suggestedRecipes);
  }

  @override
  @JsonKey()
  final double confidence;
  @override
  final String? error;

  @override
  String toString() {
    return 'PhotoSearchState(isLoading: $isLoading, detectedIngredients: $detectedIngredients, suggestedRecipes: $suggestedRecipes, confidence: $confidence, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PhotoSearchStateImpl &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            const DeepCollectionEquality()
                .equals(other._detectedIngredients, _detectedIngredients) &&
            const DeepCollectionEquality()
                .equals(other._suggestedRecipes, _suggestedRecipes) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      isLoading,
      const DeepCollectionEquality().hash(_detectedIngredients),
      const DeepCollectionEquality().hash(_suggestedRecipes),
      confidence,
      error);

  /// Create a copy of PhotoSearchState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PhotoSearchStateImplCopyWith<_$PhotoSearchStateImpl> get copyWith =>
      __$$PhotoSearchStateImplCopyWithImpl<_$PhotoSearchStateImpl>(
          this, _$identity);
}

abstract class _PhotoSearchState implements PhotoSearchState {
  const factory _PhotoSearchState(
      {final bool isLoading,
      final List<DetectedIngredient> detectedIngredients,
      final List<Map<String, dynamic>> suggestedRecipes,
      final double confidence,
      final String? error}) = _$PhotoSearchStateImpl;

  @override
  bool get isLoading;
  @override
  List<DetectedIngredient> get detectedIngredients;
  @override
  List<Map<String, dynamic>> get suggestedRecipes;
  @override
  double get confidence;
  @override
  String? get error;

  /// Create a copy of PhotoSearchState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PhotoSearchStateImplCopyWith<_$PhotoSearchStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
