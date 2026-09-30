// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'path_words_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PathWordsState {

 DateTime get day; PathWordsPuzzle? get puzzle; PathWordsStatus get status; List<Cell> get activePath; List<PathWordsStroke> get placedPaths; Set<String> get completedTargetIds; int get hintsRemaining; int get hintRevealLength; DateTime? get startedAt; Cell? get hintFlashCell; String? get errorMessage; String? get ruleTip; bool get finished; int? get points; int? get timeSeconds; bool? get improved; ResultsArgs? get resultsExtra;
/// Create a copy of PathWordsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PathWordsStateCopyWith<PathWordsState> get copyWith => _$PathWordsStateCopyWithImpl<PathWordsState>(this as PathWordsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathWordsState&&(identical(other.day, day) || other.day == day)&&(identical(other.puzzle, puzzle) || other.puzzle == puzzle)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.activePath, activePath)&&const DeepCollectionEquality().equals(other.placedPaths, placedPaths)&&const DeepCollectionEquality().equals(other.completedTargetIds, completedTargetIds)&&(identical(other.hintsRemaining, hintsRemaining) || other.hintsRemaining == hintsRemaining)&&(identical(other.hintRevealLength, hintRevealLength) || other.hintRevealLength == hintRevealLength)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.hintFlashCell, hintFlashCell) || other.hintFlashCell == hintFlashCell)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.ruleTip, ruleTip) || other.ruleTip == ruleTip)&&(identical(other.finished, finished) || other.finished == finished)&&(identical(other.points, points) || other.points == points)&&(identical(other.timeSeconds, timeSeconds) || other.timeSeconds == timeSeconds)&&(identical(other.improved, improved) || other.improved == improved)&&(identical(other.resultsExtra, resultsExtra) || other.resultsExtra == resultsExtra));
}


@override
int get hashCode => Object.hash(runtimeType,day,puzzle,status,const DeepCollectionEquality().hash(activePath),const DeepCollectionEquality().hash(placedPaths),const DeepCollectionEquality().hash(completedTargetIds),hintsRemaining,hintRevealLength,startedAt,hintFlashCell,errorMessage,ruleTip,finished,points,timeSeconds,improved,resultsExtra);

@override
String toString() {
  return 'PathWordsState(day: $day, puzzle: $puzzle, status: $status, activePath: $activePath, placedPaths: $placedPaths, completedTargetIds: $completedTargetIds, hintsRemaining: $hintsRemaining, hintRevealLength: $hintRevealLength, startedAt: $startedAt, hintFlashCell: $hintFlashCell, errorMessage: $errorMessage, ruleTip: $ruleTip, finished: $finished, points: $points, timeSeconds: $timeSeconds, improved: $improved, resultsExtra: $resultsExtra)';
}


}

/// @nodoc
abstract mixin class $PathWordsStateCopyWith<$Res>  {
  factory $PathWordsStateCopyWith(PathWordsState value, $Res Function(PathWordsState) _then) = _$PathWordsStateCopyWithImpl;
@useResult
$Res call({
 DateTime day, PathWordsPuzzle? puzzle, PathWordsStatus status, List<Cell> activePath, List<PathWordsStroke> placedPaths, Set<String> completedTargetIds, int hintsRemaining, int hintRevealLength, DateTime? startedAt, Cell? hintFlashCell, String? errorMessage, String? ruleTip, bool finished, int? points, int? timeSeconds, bool? improved, ResultsArgs? resultsExtra
});




}
/// @nodoc
class _$PathWordsStateCopyWithImpl<$Res>
    implements $PathWordsStateCopyWith<$Res> {
  _$PathWordsStateCopyWithImpl(this._self, this._then);

  final PathWordsState _self;
  final $Res Function(PathWordsState) _then;

/// Create a copy of PathWordsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? day = null,Object? puzzle = freezed,Object? status = null,Object? activePath = null,Object? placedPaths = null,Object? completedTargetIds = null,Object? hintsRemaining = null,Object? hintRevealLength = null,Object? startedAt = freezed,Object? hintFlashCell = freezed,Object? errorMessage = freezed,Object? ruleTip = freezed,Object? finished = null,Object? points = freezed,Object? timeSeconds = freezed,Object? improved = freezed,Object? resultsExtra = freezed,}) {
  return _then(_self.copyWith(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime,puzzle: freezed == puzzle ? _self.puzzle : puzzle // ignore: cast_nullable_to_non_nullable
as PathWordsPuzzle?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PathWordsStatus,activePath: null == activePath ? _self.activePath : activePath // ignore: cast_nullable_to_non_nullable
as List<Cell>,placedPaths: null == placedPaths ? _self.placedPaths : placedPaths // ignore: cast_nullable_to_non_nullable
as List<PathWordsStroke>,completedTargetIds: null == completedTargetIds ? _self.completedTargetIds : completedTargetIds // ignore: cast_nullable_to_non_nullable
as Set<String>,hintsRemaining: null == hintsRemaining ? _self.hintsRemaining : hintsRemaining // ignore: cast_nullable_to_non_nullable
as int,hintRevealLength: null == hintRevealLength ? _self.hintRevealLength : hintRevealLength // ignore: cast_nullable_to_non_nullable
as int,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,hintFlashCell: freezed == hintFlashCell ? _self.hintFlashCell : hintFlashCell // ignore: cast_nullable_to_non_nullable
as Cell?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,ruleTip: freezed == ruleTip ? _self.ruleTip : ruleTip // ignore: cast_nullable_to_non_nullable
as String?,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,points: freezed == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int?,timeSeconds: freezed == timeSeconds ? _self.timeSeconds : timeSeconds // ignore: cast_nullable_to_non_nullable
as int?,improved: freezed == improved ? _self.improved : improved // ignore: cast_nullable_to_non_nullable
as bool?,resultsExtra: freezed == resultsExtra ? _self.resultsExtra : resultsExtra // ignore: cast_nullable_to_non_nullable
as ResultsArgs?,
  ));
}

}


/// Adds pattern-matching-related methods to [PathWordsState].
extension PathWordsStatePatterns on PathWordsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PathWordsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PathWordsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PathWordsState value)  $default,){
final _that = this;
switch (_that) {
case _PathWordsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PathWordsState value)?  $default,){
final _that = this;
switch (_that) {
case _PathWordsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime day,  PathWordsPuzzle? puzzle,  PathWordsStatus status,  List<Cell> activePath,  List<PathWordsStroke> placedPaths,  Set<String> completedTargetIds,  int hintsRemaining,  int hintRevealLength,  DateTime? startedAt,  Cell? hintFlashCell,  String? errorMessage,  String? ruleTip,  bool finished,  int? points,  int? timeSeconds,  bool? improved,  ResultsArgs? resultsExtra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PathWordsState() when $default != null:
return $default(_that.day,_that.puzzle,_that.status,_that.activePath,_that.placedPaths,_that.completedTargetIds,_that.hintsRemaining,_that.hintRevealLength,_that.startedAt,_that.hintFlashCell,_that.errorMessage,_that.ruleTip,_that.finished,_that.points,_that.timeSeconds,_that.improved,_that.resultsExtra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime day,  PathWordsPuzzle? puzzle,  PathWordsStatus status,  List<Cell> activePath,  List<PathWordsStroke> placedPaths,  Set<String> completedTargetIds,  int hintsRemaining,  int hintRevealLength,  DateTime? startedAt,  Cell? hintFlashCell,  String? errorMessage,  String? ruleTip,  bool finished,  int? points,  int? timeSeconds,  bool? improved,  ResultsArgs? resultsExtra)  $default,) {final _that = this;
switch (_that) {
case _PathWordsState():
return $default(_that.day,_that.puzzle,_that.status,_that.activePath,_that.placedPaths,_that.completedTargetIds,_that.hintsRemaining,_that.hintRevealLength,_that.startedAt,_that.hintFlashCell,_that.errorMessage,_that.ruleTip,_that.finished,_that.points,_that.timeSeconds,_that.improved,_that.resultsExtra);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime day,  PathWordsPuzzle? puzzle,  PathWordsStatus status,  List<Cell> activePath,  List<PathWordsStroke> placedPaths,  Set<String> completedTargetIds,  int hintsRemaining,  int hintRevealLength,  DateTime? startedAt,  Cell? hintFlashCell,  String? errorMessage,  String? ruleTip,  bool finished,  int? points,  int? timeSeconds,  bool? improved,  ResultsArgs? resultsExtra)?  $default,) {final _that = this;
switch (_that) {
case _PathWordsState() when $default != null:
return $default(_that.day,_that.puzzle,_that.status,_that.activePath,_that.placedPaths,_that.completedTargetIds,_that.hintsRemaining,_that.hintRevealLength,_that.startedAt,_that.hintFlashCell,_that.errorMessage,_that.ruleTip,_that.finished,_that.points,_that.timeSeconds,_that.improved,_that.resultsExtra);case _:
  return null;

}
}

}

/// @nodoc


class _PathWordsState implements PathWordsState {
  const _PathWordsState({required this.day, this.puzzle, this.status = PathWordsStatus.loading, final  List<Cell> activePath = const <Cell>[], final  List<PathWordsStroke> placedPaths = const <PathWordsStroke>[], final  Set<String> completedTargetIds = const <String>{}, this.hintsRemaining = 3, this.hintRevealLength = 0, this.startedAt, this.hintFlashCell, this.errorMessage, this.ruleTip, this.finished = false, this.points, this.timeSeconds, this.improved, this.resultsExtra}): _activePath = activePath,_placedPaths = placedPaths,_completedTargetIds = completedTargetIds;
  

@override final  DateTime day;
@override final  PathWordsPuzzle? puzzle;
@override@JsonKey() final  PathWordsStatus status;
 final  List<Cell> _activePath;
@override@JsonKey() List<Cell> get activePath {
  if (_activePath is EqualUnmodifiableListView) return _activePath;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_activePath);
}

 final  List<PathWordsStroke> _placedPaths;
@override@JsonKey() List<PathWordsStroke> get placedPaths {
  if (_placedPaths is EqualUnmodifiableListView) return _placedPaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_placedPaths);
}

 final  Set<String> _completedTargetIds;
@override@JsonKey() Set<String> get completedTargetIds {
  if (_completedTargetIds is EqualUnmodifiableSetView) return _completedTargetIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_completedTargetIds);
}

@override@JsonKey() final  int hintsRemaining;
@override@JsonKey() final  int hintRevealLength;
@override final  DateTime? startedAt;
@override final  Cell? hintFlashCell;
@override final  String? errorMessage;
@override final  String? ruleTip;
@override@JsonKey() final  bool finished;
@override final  int? points;
@override final  int? timeSeconds;
@override final  bool? improved;
@override final  ResultsArgs? resultsExtra;

/// Create a copy of PathWordsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PathWordsStateCopyWith<_PathWordsState> get copyWith => __$PathWordsStateCopyWithImpl<_PathWordsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PathWordsState&&(identical(other.day, day) || other.day == day)&&(identical(other.puzzle, puzzle) || other.puzzle == puzzle)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._activePath, _activePath)&&const DeepCollectionEquality().equals(other._placedPaths, _placedPaths)&&const DeepCollectionEquality().equals(other._completedTargetIds, _completedTargetIds)&&(identical(other.hintsRemaining, hintsRemaining) || other.hintsRemaining == hintsRemaining)&&(identical(other.hintRevealLength, hintRevealLength) || other.hintRevealLength == hintRevealLength)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.hintFlashCell, hintFlashCell) || other.hintFlashCell == hintFlashCell)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.ruleTip, ruleTip) || other.ruleTip == ruleTip)&&(identical(other.finished, finished) || other.finished == finished)&&(identical(other.points, points) || other.points == points)&&(identical(other.timeSeconds, timeSeconds) || other.timeSeconds == timeSeconds)&&(identical(other.improved, improved) || other.improved == improved)&&(identical(other.resultsExtra, resultsExtra) || other.resultsExtra == resultsExtra));
}


@override
int get hashCode => Object.hash(runtimeType,day,puzzle,status,const DeepCollectionEquality().hash(_activePath),const DeepCollectionEquality().hash(_placedPaths),const DeepCollectionEquality().hash(_completedTargetIds),hintsRemaining,hintRevealLength,startedAt,hintFlashCell,errorMessage,ruleTip,finished,points,timeSeconds,improved,resultsExtra);

@override
String toString() {
  return 'PathWordsState(day: $day, puzzle: $puzzle, status: $status, activePath: $activePath, placedPaths: $placedPaths, completedTargetIds: $completedTargetIds, hintsRemaining: $hintsRemaining, hintRevealLength: $hintRevealLength, startedAt: $startedAt, hintFlashCell: $hintFlashCell, errorMessage: $errorMessage, ruleTip: $ruleTip, finished: $finished, points: $points, timeSeconds: $timeSeconds, improved: $improved, resultsExtra: $resultsExtra)';
}


}

/// @nodoc
abstract mixin class _$PathWordsStateCopyWith<$Res> implements $PathWordsStateCopyWith<$Res> {
  factory _$PathWordsStateCopyWith(_PathWordsState value, $Res Function(_PathWordsState) _then) = __$PathWordsStateCopyWithImpl;
@override @useResult
$Res call({
 DateTime day, PathWordsPuzzle? puzzle, PathWordsStatus status, List<Cell> activePath, List<PathWordsStroke> placedPaths, Set<String> completedTargetIds, int hintsRemaining, int hintRevealLength, DateTime? startedAt, Cell? hintFlashCell, String? errorMessage, String? ruleTip, bool finished, int? points, int? timeSeconds, bool? improved, ResultsArgs? resultsExtra
});




}
/// @nodoc
class __$PathWordsStateCopyWithImpl<$Res>
    implements _$PathWordsStateCopyWith<$Res> {
  __$PathWordsStateCopyWithImpl(this._self, this._then);

  final _PathWordsState _self;
  final $Res Function(_PathWordsState) _then;

/// Create a copy of PathWordsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? day = null,Object? puzzle = freezed,Object? status = null,Object? activePath = null,Object? placedPaths = null,Object? completedTargetIds = null,Object? hintsRemaining = null,Object? hintRevealLength = null,Object? startedAt = freezed,Object? hintFlashCell = freezed,Object? errorMessage = freezed,Object? ruleTip = freezed,Object? finished = null,Object? points = freezed,Object? timeSeconds = freezed,Object? improved = freezed,Object? resultsExtra = freezed,}) {
  return _then(_PathWordsState(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime,puzzle: freezed == puzzle ? _self.puzzle : puzzle // ignore: cast_nullable_to_non_nullable
as PathWordsPuzzle?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PathWordsStatus,activePath: null == activePath ? _self._activePath : activePath // ignore: cast_nullable_to_non_nullable
as List<Cell>,placedPaths: null == placedPaths ? _self._placedPaths : placedPaths // ignore: cast_nullable_to_non_nullable
as List<PathWordsStroke>,completedTargetIds: null == completedTargetIds ? _self._completedTargetIds : completedTargetIds // ignore: cast_nullable_to_non_nullable
as Set<String>,hintsRemaining: null == hintsRemaining ? _self.hintsRemaining : hintsRemaining // ignore: cast_nullable_to_non_nullable
as int,hintRevealLength: null == hintRevealLength ? _self.hintRevealLength : hintRevealLength // ignore: cast_nullable_to_non_nullable
as int,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,hintFlashCell: freezed == hintFlashCell ? _self.hintFlashCell : hintFlashCell // ignore: cast_nullable_to_non_nullable
as Cell?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,ruleTip: freezed == ruleTip ? _self.ruleTip : ruleTip // ignore: cast_nullable_to_non_nullable
as String?,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,points: freezed == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int?,timeSeconds: freezed == timeSeconds ? _self.timeSeconds : timeSeconds // ignore: cast_nullable_to_non_nullable
as int?,improved: freezed == improved ? _self.improved : improved // ignore: cast_nullable_to_non_nullable
as bool?,resultsExtra: freezed == resultsExtra ? _self.resultsExtra : resultsExtra // ignore: cast_nullable_to_non_nullable
as ResultsArgs?,
  ));
}


}

// dart format on
