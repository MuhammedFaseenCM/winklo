// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cleared_summary_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ClearedSummaryState {

 int? get timeSeconds; bool? get usedHints; bool? get hadMistakes;/// The player's place on that day's board; null while loading, signed
/// out, or outside the top entries the board loads.
 int? get rank;
/// Create a copy of ClearedSummaryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClearedSummaryStateCopyWith<ClearedSummaryState> get copyWith => _$ClearedSummaryStateCopyWithImpl<ClearedSummaryState>(this as ClearedSummaryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClearedSummaryState&&(identical(other.timeSeconds, timeSeconds) || other.timeSeconds == timeSeconds)&&(identical(other.usedHints, usedHints) || other.usedHints == usedHints)&&(identical(other.hadMistakes, hadMistakes) || other.hadMistakes == hadMistakes)&&(identical(other.rank, rank) || other.rank == rank));
}


@override
int get hashCode => Object.hash(runtimeType,timeSeconds,usedHints,hadMistakes,rank);

@override
String toString() {
  return 'ClearedSummaryState(timeSeconds: $timeSeconds, usedHints: $usedHints, hadMistakes: $hadMistakes, rank: $rank)';
}


}

/// @nodoc
abstract mixin class $ClearedSummaryStateCopyWith<$Res>  {
  factory $ClearedSummaryStateCopyWith(ClearedSummaryState value, $Res Function(ClearedSummaryState) _then) = _$ClearedSummaryStateCopyWithImpl;
@useResult
$Res call({
 int? timeSeconds, bool? usedHints, bool? hadMistakes, int? rank
});




}
/// @nodoc
class _$ClearedSummaryStateCopyWithImpl<$Res>
    implements $ClearedSummaryStateCopyWith<$Res> {
  _$ClearedSummaryStateCopyWithImpl(this._self, this._then);

  final ClearedSummaryState _self;
  final $Res Function(ClearedSummaryState) _then;

/// Create a copy of ClearedSummaryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timeSeconds = freezed,Object? usedHints = freezed,Object? hadMistakes = freezed,Object? rank = freezed,}) {
  return _then(_self.copyWith(
timeSeconds: freezed == timeSeconds ? _self.timeSeconds : timeSeconds // ignore: cast_nullable_to_non_nullable
as int?,usedHints: freezed == usedHints ? _self.usedHints : usedHints // ignore: cast_nullable_to_non_nullable
as bool?,hadMistakes: freezed == hadMistakes ? _self.hadMistakes : hadMistakes // ignore: cast_nullable_to_non_nullable
as bool?,rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ClearedSummaryState].
extension ClearedSummaryStatePatterns on ClearedSummaryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClearedSummaryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClearedSummaryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClearedSummaryState value)  $default,){
final _that = this;
switch (_that) {
case _ClearedSummaryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClearedSummaryState value)?  $default,){
final _that = this;
switch (_that) {
case _ClearedSummaryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? timeSeconds,  bool? usedHints,  bool? hadMistakes,  int? rank)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClearedSummaryState() when $default != null:
return $default(_that.timeSeconds,_that.usedHints,_that.hadMistakes,_that.rank);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? timeSeconds,  bool? usedHints,  bool? hadMistakes,  int? rank)  $default,) {final _that = this;
switch (_that) {
case _ClearedSummaryState():
return $default(_that.timeSeconds,_that.usedHints,_that.hadMistakes,_that.rank);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? timeSeconds,  bool? usedHints,  bool? hadMistakes,  int? rank)?  $default,) {final _that = this;
switch (_that) {
case _ClearedSummaryState() when $default != null:
return $default(_that.timeSeconds,_that.usedHints,_that.hadMistakes,_that.rank);case _:
  return null;

}
}

}

/// @nodoc


class _ClearedSummaryState implements ClearedSummaryState {
  const _ClearedSummaryState({this.timeSeconds, this.usedHints, this.hadMistakes, this.rank});
  

@override final  int? timeSeconds;
@override final  bool? usedHints;
@override final  bool? hadMistakes;
/// The player's place on that day's board; null while loading, signed
/// out, or outside the top entries the board loads.
@override final  int? rank;

/// Create a copy of ClearedSummaryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClearedSummaryStateCopyWith<_ClearedSummaryState> get copyWith => __$ClearedSummaryStateCopyWithImpl<_ClearedSummaryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClearedSummaryState&&(identical(other.timeSeconds, timeSeconds) || other.timeSeconds == timeSeconds)&&(identical(other.usedHints, usedHints) || other.usedHints == usedHints)&&(identical(other.hadMistakes, hadMistakes) || other.hadMistakes == hadMistakes)&&(identical(other.rank, rank) || other.rank == rank));
}


@override
int get hashCode => Object.hash(runtimeType,timeSeconds,usedHints,hadMistakes,rank);

@override
String toString() {
  return 'ClearedSummaryState(timeSeconds: $timeSeconds, usedHints: $usedHints, hadMistakes: $hadMistakes, rank: $rank)';
}


}

/// @nodoc
abstract mixin class _$ClearedSummaryStateCopyWith<$Res> implements $ClearedSummaryStateCopyWith<$Res> {
  factory _$ClearedSummaryStateCopyWith(_ClearedSummaryState value, $Res Function(_ClearedSummaryState) _then) = __$ClearedSummaryStateCopyWithImpl;
@override @useResult
$Res call({
 int? timeSeconds, bool? usedHints, bool? hadMistakes, int? rank
});




}
/// @nodoc
class __$ClearedSummaryStateCopyWithImpl<$Res>
    implements _$ClearedSummaryStateCopyWith<$Res> {
  __$ClearedSummaryStateCopyWithImpl(this._self, this._then);

  final _ClearedSummaryState _self;
  final $Res Function(_ClearedSummaryState) _then;

/// Create a copy of ClearedSummaryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timeSeconds = freezed,Object? usedHints = freezed,Object? hadMistakes = freezed,Object? rank = freezed,}) {
  return _then(_ClearedSummaryState(
timeSeconds: freezed == timeSeconds ? _self.timeSeconds : timeSeconds // ignore: cast_nullable_to_non_nullable
as int?,usedHints: freezed == usedHints ? _self.usedHints : usedHints // ignore: cast_nullable_to_non_nullable
as bool?,hadMistakes: freezed == hadMistakes ? _self.hadMistakes : hadMistakes // ignore: cast_nullable_to_non_nullable
as bool?,rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
