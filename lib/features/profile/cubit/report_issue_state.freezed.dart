// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'report_issue_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReportIssueState {

 ReportIssueStatus get status; String get titleDraft; String get descriptionDraft; String? get error;
/// Create a copy of ReportIssueState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReportIssueStateCopyWith<ReportIssueState> get copyWith => _$ReportIssueStateCopyWithImpl<ReportIssueState>(this as ReportIssueState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReportIssueState&&(identical(other.status, status) || other.status == status)&&(identical(other.titleDraft, titleDraft) || other.titleDraft == titleDraft)&&(identical(other.descriptionDraft, descriptionDraft) || other.descriptionDraft == descriptionDraft)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,status,titleDraft,descriptionDraft,error);

@override
String toString() {
  return 'ReportIssueState(status: $status, titleDraft: $titleDraft, descriptionDraft: $descriptionDraft, error: $error)';
}


}

/// @nodoc
abstract mixin class $ReportIssueStateCopyWith<$Res>  {
  factory $ReportIssueStateCopyWith(ReportIssueState value, $Res Function(ReportIssueState) _then) = _$ReportIssueStateCopyWithImpl;
@useResult
$Res call({
 ReportIssueStatus status, String titleDraft, String descriptionDraft, String? error
});




}
/// @nodoc
class _$ReportIssueStateCopyWithImpl<$Res>
    implements $ReportIssueStateCopyWith<$Res> {
  _$ReportIssueStateCopyWithImpl(this._self, this._then);

  final ReportIssueState _self;
  final $Res Function(ReportIssueState) _then;

/// Create a copy of ReportIssueState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? titleDraft = null,Object? descriptionDraft = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ReportIssueStatus,titleDraft: null == titleDraft ? _self.titleDraft : titleDraft // ignore: cast_nullable_to_non_nullable
as String,descriptionDraft: null == descriptionDraft ? _self.descriptionDraft : descriptionDraft // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReportIssueState].
extension ReportIssueStatePatterns on ReportIssueState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReportIssueState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReportIssueState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReportIssueState value)  $default,){
final _that = this;
switch (_that) {
case _ReportIssueState():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReportIssueState value)?  $default,){
final _that = this;
switch (_that) {
case _ReportIssueState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ReportIssueStatus status,  String titleDraft,  String descriptionDraft,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReportIssueState() when $default != null:
return $default(_that.status,_that.titleDraft,_that.descriptionDraft,_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ReportIssueStatus status,  String titleDraft,  String descriptionDraft,  String? error)  $default,) {final _that = this;
switch (_that) {
case _ReportIssueState():
return $default(_that.status,_that.titleDraft,_that.descriptionDraft,_that.error);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ReportIssueStatus status,  String titleDraft,  String descriptionDraft,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _ReportIssueState() when $default != null:
return $default(_that.status,_that.titleDraft,_that.descriptionDraft,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _ReportIssueState implements ReportIssueState {
  const _ReportIssueState({this.status = ReportIssueStatus.idle, this.titleDraft = '', this.descriptionDraft = '', this.error});
  

@override@JsonKey() final  ReportIssueStatus status;
@override@JsonKey() final  String titleDraft;
@override@JsonKey() final  String descriptionDraft;
@override final  String? error;

/// Create a copy of ReportIssueState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReportIssueStateCopyWith<_ReportIssueState> get copyWith => __$ReportIssueStateCopyWithImpl<_ReportIssueState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReportIssueState&&(identical(other.status, status) || other.status == status)&&(identical(other.titleDraft, titleDraft) || other.titleDraft == titleDraft)&&(identical(other.descriptionDraft, descriptionDraft) || other.descriptionDraft == descriptionDraft)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,status,titleDraft,descriptionDraft,error);

@override
String toString() {
  return 'ReportIssueState(status: $status, titleDraft: $titleDraft, descriptionDraft: $descriptionDraft, error: $error)';
}


}

/// @nodoc
abstract mixin class _$ReportIssueStateCopyWith<$Res> implements $ReportIssueStateCopyWith<$Res> {
  factory _$ReportIssueStateCopyWith(_ReportIssueState value, $Res Function(_ReportIssueState) _then) = __$ReportIssueStateCopyWithImpl;
@override @useResult
$Res call({
 ReportIssueStatus status, String titleDraft, String descriptionDraft, String? error
});




}
/// @nodoc
class __$ReportIssueStateCopyWithImpl<$Res>
    implements _$ReportIssueStateCopyWith<$Res> {
  __$ReportIssueStateCopyWithImpl(this._self, this._then);

  final _ReportIssueState _self;
  final $Res Function(_ReportIssueState) _then;

/// Create a copy of ReportIssueState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? titleDraft = null,Object? descriptionDraft = null,Object? error = freezed,}) {
  return _then(_ReportIssueState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ReportIssueStatus,titleDraft: null == titleDraft ? _self.titleDraft : titleDraft // ignore: cast_nullable_to_non_nullable
as String,descriptionDraft: null == descriptionDraft ? _self.descriptionDraft : descriptionDraft // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
