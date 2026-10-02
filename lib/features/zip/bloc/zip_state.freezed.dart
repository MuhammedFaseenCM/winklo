// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'zip_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ZipState {

 DateTime get day; ZipLevel get level; ZipStatus get status; bool get finished; bool get usedHintsThisRun; int get elapsedMs; DateTime? get resumedAt; List<Cell> get path; bool? get improved; int? get points; int? get timeSeconds; ResultsArgs? get resultsExtra;
/// Create a copy of ZipState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ZipStateCopyWith<ZipState> get copyWith => _$ZipStateCopyWithImpl<ZipState>(this as ZipState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ZipState&&(identical(other.day, day) || other.day == day)&&(identical(other.level, level) || other.level == level)&&(identical(other.status, status) || other.status == status)&&(identical(other.finished, finished) || other.finished == finished)&&(identical(other.usedHintsThisRun, usedHintsThisRun) || other.usedHintsThisRun == usedHintsThisRun)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs)&&(identical(other.resumedAt, resumedAt) || other.resumedAt == resumedAt)&&const DeepCollectionEquality().equals(other.path, path)&&(identical(other.improved, improved) || other.improved == improved)&&(identical(other.points, points) || other.points == points)&&(identical(other.timeSeconds, timeSeconds) || other.timeSeconds == timeSeconds)&&(identical(other.resultsExtra, resultsExtra) || other.resultsExtra == resultsExtra));
}


@override
int get hashCode => Object.hash(runtimeType,day,level,status,finished,usedHintsThisRun,elapsedMs,resumedAt,const DeepCollectionEquality().hash(path),improved,points,timeSeconds,resultsExtra);

@override
String toString() {
  return 'ZipState(day: $day, level: $level, status: $status, finished: $finished, usedHintsThisRun: $usedHintsThisRun, elapsedMs: $elapsedMs, resumedAt: $resumedAt, path: $path, improved: $improved, points: $points, timeSeconds: $timeSeconds, resultsExtra: $resultsExtra)';
}


}

/// @nodoc
abstract mixin class $ZipStateCopyWith<$Res>  {
  factory $ZipStateCopyWith(ZipState value, $Res Function(ZipState) _then) = _$ZipStateCopyWithImpl;
@useResult
$Res call({
 DateTime day, ZipLevel level, ZipStatus status, bool finished, bool usedHintsThisRun, int elapsedMs, DateTime? resumedAt, List<Cell> path, bool? improved, int? points, int? timeSeconds, ResultsArgs? resultsExtra
});




}
/// @nodoc
class _$ZipStateCopyWithImpl<$Res>
    implements $ZipStateCopyWith<$Res> {
  _$ZipStateCopyWithImpl(this._self, this._then);

  final ZipState _self;
  final $Res Function(ZipState) _then;

/// Create a copy of ZipState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? day = null,Object? level = null,Object? status = null,Object? finished = null,Object? usedHintsThisRun = null,Object? elapsedMs = null,Object? resumedAt = freezed,Object? path = null,Object? improved = freezed,Object? points = freezed,Object? timeSeconds = freezed,Object? resultsExtra = freezed,}) {
  return _then(_self.copyWith(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as ZipLevel,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ZipStatus,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,usedHintsThisRun: null == usedHintsThisRun ? _self.usedHintsThisRun : usedHintsThisRun // ignore: cast_nullable_to_non_nullable
as bool,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,resumedAt: freezed == resumedAt ? _self.resumedAt : resumedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as List<Cell>,improved: freezed == improved ? _self.improved : improved // ignore: cast_nullable_to_non_nullable
as bool?,points: freezed == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int?,timeSeconds: freezed == timeSeconds ? _self.timeSeconds : timeSeconds // ignore: cast_nullable_to_non_nullable
as int?,resultsExtra: freezed == resultsExtra ? _self.resultsExtra : resultsExtra // ignore: cast_nullable_to_non_nullable
as ResultsArgs?,
  ));
}

}


/// Adds pattern-matching-related methods to [ZipState].
extension ZipStatePatterns on ZipState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ZipState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ZipState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ZipState value)  $default,){
final _that = this;
switch (_that) {
case _ZipState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ZipState value)?  $default,){
final _that = this;
switch (_that) {
case _ZipState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime day,  ZipLevel level,  ZipStatus status,  bool finished,  bool usedHintsThisRun,  int elapsedMs,  DateTime? resumedAt,  List<Cell> path,  bool? improved,  int? points,  int? timeSeconds,  ResultsArgs? resultsExtra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ZipState() when $default != null:
return $default(_that.day,_that.level,_that.status,_that.finished,_that.usedHintsThisRun,_that.elapsedMs,_that.resumedAt,_that.path,_that.improved,_that.points,_that.timeSeconds,_that.resultsExtra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime day,  ZipLevel level,  ZipStatus status,  bool finished,  bool usedHintsThisRun,  int elapsedMs,  DateTime? resumedAt,  List<Cell> path,  bool? improved,  int? points,  int? timeSeconds,  ResultsArgs? resultsExtra)  $default,) {final _that = this;
switch (_that) {
case _ZipState():
return $default(_that.day,_that.level,_that.status,_that.finished,_that.usedHintsThisRun,_that.elapsedMs,_that.resumedAt,_that.path,_that.improved,_that.points,_that.timeSeconds,_that.resultsExtra);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime day,  ZipLevel level,  ZipStatus status,  bool finished,  bool usedHintsThisRun,  int elapsedMs,  DateTime? resumedAt,  List<Cell> path,  bool? improved,  int? points,  int? timeSeconds,  ResultsArgs? resultsExtra)?  $default,) {final _that = this;
switch (_that) {
case _ZipState() when $default != null:
return $default(_that.day,_that.level,_that.status,_that.finished,_that.usedHintsThisRun,_that.elapsedMs,_that.resumedAt,_that.path,_that.improved,_that.points,_that.timeSeconds,_that.resultsExtra);case _:
  return null;

}
}

}

/// @nodoc


class _ZipState extends ZipState {
  const _ZipState({required this.day, required this.level, this.status = ZipStatus.ready, this.finished = false, this.usedHintsThisRun = false, this.elapsedMs = 0, this.resumedAt, final  List<Cell> path = const <Cell>[], this.improved, this.points, this.timeSeconds, this.resultsExtra}): _path = path,super._();
  

@override final  DateTime day;
@override final  ZipLevel level;
@override@JsonKey() final  ZipStatus status;
@override@JsonKey() final  bool finished;
@override@JsonKey() final  bool usedHintsThisRun;
@override@JsonKey() final  int elapsedMs;
@override final  DateTime? resumedAt;
 final  List<Cell> _path;
@override@JsonKey() List<Cell> get path {
  if (_path is EqualUnmodifiableListView) return _path;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_path);
}

@override final  bool? improved;
@override final  int? points;
@override final  int? timeSeconds;
@override final  ResultsArgs? resultsExtra;

/// Create a copy of ZipState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ZipStateCopyWith<_ZipState> get copyWith => __$ZipStateCopyWithImpl<_ZipState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ZipState&&(identical(other.day, day) || other.day == day)&&(identical(other.level, level) || other.level == level)&&(identical(other.status, status) || other.status == status)&&(identical(other.finished, finished) || other.finished == finished)&&(identical(other.usedHintsThisRun, usedHintsThisRun) || other.usedHintsThisRun == usedHintsThisRun)&&(identical(other.elapsedMs, elapsedMs) || other.elapsedMs == elapsedMs)&&(identical(other.resumedAt, resumedAt) || other.resumedAt == resumedAt)&&const DeepCollectionEquality().equals(other._path, _path)&&(identical(other.improved, improved) || other.improved == improved)&&(identical(other.points, points) || other.points == points)&&(identical(other.timeSeconds, timeSeconds) || other.timeSeconds == timeSeconds)&&(identical(other.resultsExtra, resultsExtra) || other.resultsExtra == resultsExtra));
}


@override
int get hashCode => Object.hash(runtimeType,day,level,status,finished,usedHintsThisRun,elapsedMs,resumedAt,const DeepCollectionEquality().hash(_path),improved,points,timeSeconds,resultsExtra);

@override
String toString() {
  return 'ZipState(day: $day, level: $level, status: $status, finished: $finished, usedHintsThisRun: $usedHintsThisRun, elapsedMs: $elapsedMs, resumedAt: $resumedAt, path: $path, improved: $improved, points: $points, timeSeconds: $timeSeconds, resultsExtra: $resultsExtra)';
}


}

/// @nodoc
abstract mixin class _$ZipStateCopyWith<$Res> implements $ZipStateCopyWith<$Res> {
  factory _$ZipStateCopyWith(_ZipState value, $Res Function(_ZipState) _then) = __$ZipStateCopyWithImpl;
@override @useResult
$Res call({
 DateTime day, ZipLevel level, ZipStatus status, bool finished, bool usedHintsThisRun, int elapsedMs, DateTime? resumedAt, List<Cell> path, bool? improved, int? points, int? timeSeconds, ResultsArgs? resultsExtra
});




}
/// @nodoc
class __$ZipStateCopyWithImpl<$Res>
    implements _$ZipStateCopyWith<$Res> {
  __$ZipStateCopyWithImpl(this._self, this._then);

  final _ZipState _self;
  final $Res Function(_ZipState) _then;

/// Create a copy of ZipState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? day = null,Object? level = null,Object? status = null,Object? finished = null,Object? usedHintsThisRun = null,Object? elapsedMs = null,Object? resumedAt = freezed,Object? path = null,Object? improved = freezed,Object? points = freezed,Object? timeSeconds = freezed,Object? resultsExtra = freezed,}) {
  return _then(_ZipState(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as ZipLevel,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ZipStatus,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,usedHintsThisRun: null == usedHintsThisRun ? _self.usedHintsThisRun : usedHintsThisRun // ignore: cast_nullable_to_non_nullable
as bool,elapsedMs: null == elapsedMs ? _self.elapsedMs : elapsedMs // ignore: cast_nullable_to_non_nullable
as int,resumedAt: freezed == resumedAt ? _self.resumedAt : resumedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,path: null == path ? _self._path : path // ignore: cast_nullable_to_non_nullable
as List<Cell>,improved: freezed == improved ? _self.improved : improved // ignore: cast_nullable_to_non_nullable
as bool?,points: freezed == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int?,timeSeconds: freezed == timeSeconds ? _self.timeSeconds : timeSeconds // ignore: cast_nullable_to_non_nullable
as int?,resultsExtra: freezed == resultsExtra ? _self.resultsExtra : resultsExtra // ignore: cast_nullable_to_non_nullable
as ResultsArgs?,
  ));
}


}

// dart format on
