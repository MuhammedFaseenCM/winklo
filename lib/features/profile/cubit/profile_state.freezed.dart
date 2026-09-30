// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProfileState {

 ProfileStatus get status; AppUser? get profile; String? get error; ProfileFailureKind get failureKind; String get nameDraft; bool get nameDraftTouched;
/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileStateCopyWith<ProfileState> get copyWith => _$ProfileStateCopyWithImpl<ProfileState>(this as ProfileState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileState&&(identical(other.status, status) || other.status == status)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.error, error) || other.error == error)&&(identical(other.failureKind, failureKind) || other.failureKind == failureKind)&&(identical(other.nameDraft, nameDraft) || other.nameDraft == nameDraft)&&(identical(other.nameDraftTouched, nameDraftTouched) || other.nameDraftTouched == nameDraftTouched));
}


@override
int get hashCode => Object.hash(runtimeType,status,profile,error,failureKind,nameDraft,nameDraftTouched);

@override
String toString() {
  return 'ProfileState(status: $status, profile: $profile, error: $error, failureKind: $failureKind, nameDraft: $nameDraft, nameDraftTouched: $nameDraftTouched)';
}


}

/// @nodoc
abstract mixin class $ProfileStateCopyWith<$Res>  {
  factory $ProfileStateCopyWith(ProfileState value, $Res Function(ProfileState) _then) = _$ProfileStateCopyWithImpl;
@useResult
$Res call({
 ProfileStatus status, AppUser? profile, String? error, ProfileFailureKind failureKind, String nameDraft, bool nameDraftTouched
});




}
/// @nodoc
class _$ProfileStateCopyWithImpl<$Res>
    implements $ProfileStateCopyWith<$Res> {
  _$ProfileStateCopyWithImpl(this._self, this._then);

  final ProfileState _self;
  final $Res Function(ProfileState) _then;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? profile = freezed,Object? error = freezed,Object? failureKind = null,Object? nameDraft = null,Object? nameDraftTouched = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProfileStatus,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as AppUser?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,failureKind: null == failureKind ? _self.failureKind : failureKind // ignore: cast_nullable_to_non_nullable
as ProfileFailureKind,nameDraft: null == nameDraft ? _self.nameDraft : nameDraft // ignore: cast_nullable_to_non_nullable
as String,nameDraftTouched: null == nameDraftTouched ? _self.nameDraftTouched : nameDraftTouched // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileState].
extension ProfileStatePatterns on ProfileState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileState value)  $default,){
final _that = this;
switch (_that) {
case _ProfileState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileState value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProfileStatus status,  AppUser? profile,  String? error,  ProfileFailureKind failureKind,  String nameDraft,  bool nameDraftTouched)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileState() when $default != null:
return $default(_that.status,_that.profile,_that.error,_that.failureKind,_that.nameDraft,_that.nameDraftTouched);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProfileStatus status,  AppUser? profile,  String? error,  ProfileFailureKind failureKind,  String nameDraft,  bool nameDraftTouched)  $default,) {final _that = this;
switch (_that) {
case _ProfileState():
return $default(_that.status,_that.profile,_that.error,_that.failureKind,_that.nameDraft,_that.nameDraftTouched);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProfileStatus status,  AppUser? profile,  String? error,  ProfileFailureKind failureKind,  String nameDraft,  bool nameDraftTouched)?  $default,) {final _that = this;
switch (_that) {
case _ProfileState() when $default != null:
return $default(_that.status,_that.profile,_that.error,_that.failureKind,_that.nameDraft,_that.nameDraftTouched);case _:
  return null;

}
}

}

/// @nodoc


class _ProfileState implements ProfileState {
  const _ProfileState({this.status = ProfileStatus.idle, this.profile, this.error, this.failureKind = ProfileFailureKind.none, this.nameDraft = '', this.nameDraftTouched = false});
  

@override@JsonKey() final  ProfileStatus status;
@override final  AppUser? profile;
@override final  String? error;
@override@JsonKey() final  ProfileFailureKind failureKind;
@override@JsonKey() final  String nameDraft;
@override@JsonKey() final  bool nameDraftTouched;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileStateCopyWith<_ProfileState> get copyWith => __$ProfileStateCopyWithImpl<_ProfileState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileState&&(identical(other.status, status) || other.status == status)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.error, error) || other.error == error)&&(identical(other.failureKind, failureKind) || other.failureKind == failureKind)&&(identical(other.nameDraft, nameDraft) || other.nameDraft == nameDraft)&&(identical(other.nameDraftTouched, nameDraftTouched) || other.nameDraftTouched == nameDraftTouched));
}


@override
int get hashCode => Object.hash(runtimeType,status,profile,error,failureKind,nameDraft,nameDraftTouched);

@override
String toString() {
  return 'ProfileState(status: $status, profile: $profile, error: $error, failureKind: $failureKind, nameDraft: $nameDraft, nameDraftTouched: $nameDraftTouched)';
}


}

/// @nodoc
abstract mixin class _$ProfileStateCopyWith<$Res> implements $ProfileStateCopyWith<$Res> {
  factory _$ProfileStateCopyWith(_ProfileState value, $Res Function(_ProfileState) _then) = __$ProfileStateCopyWithImpl;
@override @useResult
$Res call({
 ProfileStatus status, AppUser? profile, String? error, ProfileFailureKind failureKind, String nameDraft, bool nameDraftTouched
});




}
/// @nodoc
class __$ProfileStateCopyWithImpl<$Res>
    implements _$ProfileStateCopyWith<$Res> {
  __$ProfileStateCopyWithImpl(this._self, this._then);

  final _ProfileState _self;
  final $Res Function(_ProfileState) _then;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? profile = freezed,Object? error = freezed,Object? failureKind = null,Object? nameDraft = null,Object? nameDraftTouched = null,}) {
  return _then(_ProfileState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProfileStatus,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as AppUser?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,failureKind: null == failureKind ? _self.failureKind : failureKind // ignore: cast_nullable_to_non_nullable
as ProfileFailureKind,nameDraft: null == nameDraft ? _self.nameDraft : nameDraft // ignore: cast_nullable_to_non_nullable
as String,nameDraftTouched: null == nameDraftTouched ? _self.nameDraftTouched : nameDraftTouched // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
