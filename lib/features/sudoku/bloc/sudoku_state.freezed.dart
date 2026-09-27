// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sudoku_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SudokuState {

 DateTime get day; SudokuPuzzle? get puzzle; List<int> get grid; List<Set<int>> get notes; int? get selectedIndex; bool get notesMode; SudokuStatus get status; DateTime? get startedAt; int? get hintFlashIndex; int? get rejectFlashIndex; Set<int> get unitFlashIndices; Set<String> get celebratedUnitIds; bool get finished; int? get points; int? get timeSeconds; bool? get improved; ResultsArgs? get resultsExtra;
/// Create a copy of SudokuState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SudokuStateCopyWith<SudokuState> get copyWith => _$SudokuStateCopyWithImpl<SudokuState>(this as SudokuState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SudokuState&&(identical(other.day, day) || other.day == day)&&(identical(other.puzzle, puzzle) || other.puzzle == puzzle)&&const DeepCollectionEquality().equals(other.grid, grid)&&const DeepCollectionEquality().equals(other.notes, notes)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex)&&(identical(other.notesMode, notesMode) || other.notesMode == notesMode)&&(identical(other.status, status) || other.status == status)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.hintFlashIndex, hintFlashIndex) || other.hintFlashIndex == hintFlashIndex)&&(identical(other.rejectFlashIndex, rejectFlashIndex) || other.rejectFlashIndex == rejectFlashIndex)&&const DeepCollectionEquality().equals(other.unitFlashIndices, unitFlashIndices)&&const DeepCollectionEquality().equals(other.celebratedUnitIds, celebratedUnitIds)&&(identical(other.finished, finished) || other.finished == finished)&&(identical(other.points, points) || other.points == points)&&(identical(other.timeSeconds, timeSeconds) || other.timeSeconds == timeSeconds)&&(identical(other.improved, improved) || other.improved == improved)&&(identical(other.resultsExtra, resultsExtra) || other.resultsExtra == resultsExtra));
}


@override
int get hashCode => Object.hash(runtimeType,day,puzzle,const DeepCollectionEquality().hash(grid),const DeepCollectionEquality().hash(notes),selectedIndex,notesMode,status,startedAt,hintFlashIndex,rejectFlashIndex,const DeepCollectionEquality().hash(unitFlashIndices),const DeepCollectionEquality().hash(celebratedUnitIds),finished,points,timeSeconds,improved,resultsExtra);

@override
String toString() {
  return 'SudokuState(day: $day, puzzle: $puzzle, grid: $grid, notes: $notes, selectedIndex: $selectedIndex, notesMode: $notesMode, status: $status, startedAt: $startedAt, hintFlashIndex: $hintFlashIndex, rejectFlashIndex: $rejectFlashIndex, unitFlashIndices: $unitFlashIndices, celebratedUnitIds: $celebratedUnitIds, finished: $finished, points: $points, timeSeconds: $timeSeconds, improved: $improved, resultsExtra: $resultsExtra)';
}


}

/// @nodoc
abstract mixin class $SudokuStateCopyWith<$Res>  {
  factory $SudokuStateCopyWith(SudokuState value, $Res Function(SudokuState) _then) = _$SudokuStateCopyWithImpl;
@useResult
$Res call({
 DateTime day, SudokuPuzzle? puzzle, List<int> grid, List<Set<int>> notes, int? selectedIndex, bool notesMode, SudokuStatus status, DateTime? startedAt, int? hintFlashIndex, int? rejectFlashIndex, Set<int> unitFlashIndices, Set<String> celebratedUnitIds, bool finished, int? points, int? timeSeconds, bool? improved, ResultsArgs? resultsExtra
});




}
/// @nodoc
class _$SudokuStateCopyWithImpl<$Res>
    implements $SudokuStateCopyWith<$Res> {
  _$SudokuStateCopyWithImpl(this._self, this._then);

  final SudokuState _self;
  final $Res Function(SudokuState) _then;

/// Create a copy of SudokuState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? day = null,Object? puzzle = freezed,Object? grid = null,Object? notes = null,Object? selectedIndex = freezed,Object? notesMode = null,Object? status = null,Object? startedAt = freezed,Object? hintFlashIndex = freezed,Object? rejectFlashIndex = freezed,Object? unitFlashIndices = null,Object? celebratedUnitIds = null,Object? finished = null,Object? points = freezed,Object? timeSeconds = freezed,Object? improved = freezed,Object? resultsExtra = freezed,}) {
  return _then(_self.copyWith(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime,puzzle: freezed == puzzle ? _self.puzzle : puzzle // ignore: cast_nullable_to_non_nullable
as SudokuPuzzle?,grid: null == grid ? _self.grid : grid // ignore: cast_nullable_to_non_nullable
as List<int>,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as List<Set<int>>,selectedIndex: freezed == selectedIndex ? _self.selectedIndex : selectedIndex // ignore: cast_nullable_to_non_nullable
as int?,notesMode: null == notesMode ? _self.notesMode : notesMode // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SudokuStatus,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,hintFlashIndex: freezed == hintFlashIndex ? _self.hintFlashIndex : hintFlashIndex // ignore: cast_nullable_to_non_nullable
as int?,rejectFlashIndex: freezed == rejectFlashIndex ? _self.rejectFlashIndex : rejectFlashIndex // ignore: cast_nullable_to_non_nullable
as int?,unitFlashIndices: null == unitFlashIndices ? _self.unitFlashIndices : unitFlashIndices // ignore: cast_nullable_to_non_nullable
as Set<int>,celebratedUnitIds: null == celebratedUnitIds ? _self.celebratedUnitIds : celebratedUnitIds // ignore: cast_nullable_to_non_nullable
as Set<String>,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,points: freezed == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int?,timeSeconds: freezed == timeSeconds ? _self.timeSeconds : timeSeconds // ignore: cast_nullable_to_non_nullable
as int?,improved: freezed == improved ? _self.improved : improved // ignore: cast_nullable_to_non_nullable
as bool?,resultsExtra: freezed == resultsExtra ? _self.resultsExtra : resultsExtra // ignore: cast_nullable_to_non_nullable
as ResultsArgs?,
  ));
}

}


/// Adds pattern-matching-related methods to [SudokuState].
extension SudokuStatePatterns on SudokuState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SudokuState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SudokuState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SudokuState value)  $default,){
final _that = this;
switch (_that) {
case _SudokuState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SudokuState value)?  $default,){
final _that = this;
switch (_that) {
case _SudokuState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime day,  SudokuPuzzle? puzzle,  List<int> grid,  List<Set<int>> notes,  int? selectedIndex,  bool notesMode,  SudokuStatus status,  DateTime? startedAt,  int? hintFlashIndex,  int? rejectFlashIndex,  Set<int> unitFlashIndices,  Set<String> celebratedUnitIds,  bool finished,  int? points,  int? timeSeconds,  bool? improved,  ResultsArgs? resultsExtra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SudokuState() when $default != null:
return $default(_that.day,_that.puzzle,_that.grid,_that.notes,_that.selectedIndex,_that.notesMode,_that.status,_that.startedAt,_that.hintFlashIndex,_that.rejectFlashIndex,_that.unitFlashIndices,_that.celebratedUnitIds,_that.finished,_that.points,_that.timeSeconds,_that.improved,_that.resultsExtra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime day,  SudokuPuzzle? puzzle,  List<int> grid,  List<Set<int>> notes,  int? selectedIndex,  bool notesMode,  SudokuStatus status,  DateTime? startedAt,  int? hintFlashIndex,  int? rejectFlashIndex,  Set<int> unitFlashIndices,  Set<String> celebratedUnitIds,  bool finished,  int? points,  int? timeSeconds,  bool? improved,  ResultsArgs? resultsExtra)  $default,) {final _that = this;
switch (_that) {
case _SudokuState():
return $default(_that.day,_that.puzzle,_that.grid,_that.notes,_that.selectedIndex,_that.notesMode,_that.status,_that.startedAt,_that.hintFlashIndex,_that.rejectFlashIndex,_that.unitFlashIndices,_that.celebratedUnitIds,_that.finished,_that.points,_that.timeSeconds,_that.improved,_that.resultsExtra);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime day,  SudokuPuzzle? puzzle,  List<int> grid,  List<Set<int>> notes,  int? selectedIndex,  bool notesMode,  SudokuStatus status,  DateTime? startedAt,  int? hintFlashIndex,  int? rejectFlashIndex,  Set<int> unitFlashIndices,  Set<String> celebratedUnitIds,  bool finished,  int? points,  int? timeSeconds,  bool? improved,  ResultsArgs? resultsExtra)?  $default,) {final _that = this;
switch (_that) {
case _SudokuState() when $default != null:
return $default(_that.day,_that.puzzle,_that.grid,_that.notes,_that.selectedIndex,_that.notesMode,_that.status,_that.startedAt,_that.hintFlashIndex,_that.rejectFlashIndex,_that.unitFlashIndices,_that.celebratedUnitIds,_that.finished,_that.points,_that.timeSeconds,_that.improved,_that.resultsExtra);case _:
  return null;

}
}

}

/// @nodoc


class _SudokuState implements SudokuState {
  const _SudokuState({required this.day, this.puzzle, final  List<int> grid = const <int>[], final  List<Set<int>> notes = const <Set<int>>[], this.selectedIndex, this.notesMode = false, this.status = SudokuStatus.loading, this.startedAt, this.hintFlashIndex, this.rejectFlashIndex, final  Set<int> unitFlashIndices = const <int>{}, final  Set<String> celebratedUnitIds = const <String>{}, this.finished = false, this.points, this.timeSeconds, this.improved, this.resultsExtra}): _grid = grid,_notes = notes,_unitFlashIndices = unitFlashIndices,_celebratedUnitIds = celebratedUnitIds;
  

@override final  DateTime day;
@override final  SudokuPuzzle? puzzle;
 final  List<int> _grid;
@override@JsonKey() List<int> get grid {
  if (_grid is EqualUnmodifiableListView) return _grid;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_grid);
}

 final  List<Set<int>> _notes;
@override@JsonKey() List<Set<int>> get notes {
  if (_notes is EqualUnmodifiableListView) return _notes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_notes);
}

@override final  int? selectedIndex;
@override@JsonKey() final  bool notesMode;
@override@JsonKey() final  SudokuStatus status;
@override final  DateTime? startedAt;
@override final  int? hintFlashIndex;
@override final  int? rejectFlashIndex;
 final  Set<int> _unitFlashIndices;
@override@JsonKey() Set<int> get unitFlashIndices {
  if (_unitFlashIndices is EqualUnmodifiableSetView) return _unitFlashIndices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_unitFlashIndices);
}

 final  Set<String> _celebratedUnitIds;
@override@JsonKey() Set<String> get celebratedUnitIds {
  if (_celebratedUnitIds is EqualUnmodifiableSetView) return _celebratedUnitIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_celebratedUnitIds);
}

@override@JsonKey() final  bool finished;
@override final  int? points;
@override final  int? timeSeconds;
@override final  bool? improved;
@override final  ResultsArgs? resultsExtra;

/// Create a copy of SudokuState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SudokuStateCopyWith<_SudokuState> get copyWith => __$SudokuStateCopyWithImpl<_SudokuState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SudokuState&&(identical(other.day, day) || other.day == day)&&(identical(other.puzzle, puzzle) || other.puzzle == puzzle)&&const DeepCollectionEquality().equals(other._grid, _grid)&&const DeepCollectionEquality().equals(other._notes, _notes)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex)&&(identical(other.notesMode, notesMode) || other.notesMode == notesMode)&&(identical(other.status, status) || other.status == status)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.hintFlashIndex, hintFlashIndex) || other.hintFlashIndex == hintFlashIndex)&&(identical(other.rejectFlashIndex, rejectFlashIndex) || other.rejectFlashIndex == rejectFlashIndex)&&const DeepCollectionEquality().equals(other._unitFlashIndices, _unitFlashIndices)&&const DeepCollectionEquality().equals(other._celebratedUnitIds, _celebratedUnitIds)&&(identical(other.finished, finished) || other.finished == finished)&&(identical(other.points, points) || other.points == points)&&(identical(other.timeSeconds, timeSeconds) || other.timeSeconds == timeSeconds)&&(identical(other.improved, improved) || other.improved == improved)&&(identical(other.resultsExtra, resultsExtra) || other.resultsExtra == resultsExtra));
}


@override
int get hashCode => Object.hash(runtimeType,day,puzzle,const DeepCollectionEquality().hash(_grid),const DeepCollectionEquality().hash(_notes),selectedIndex,notesMode,status,startedAt,hintFlashIndex,rejectFlashIndex,const DeepCollectionEquality().hash(_unitFlashIndices),const DeepCollectionEquality().hash(_celebratedUnitIds),finished,points,timeSeconds,improved,resultsExtra);

@override
String toString() {
  return 'SudokuState(day: $day, puzzle: $puzzle, grid: $grid, notes: $notes, selectedIndex: $selectedIndex, notesMode: $notesMode, status: $status, startedAt: $startedAt, hintFlashIndex: $hintFlashIndex, rejectFlashIndex: $rejectFlashIndex, unitFlashIndices: $unitFlashIndices, celebratedUnitIds: $celebratedUnitIds, finished: $finished, points: $points, timeSeconds: $timeSeconds, improved: $improved, resultsExtra: $resultsExtra)';
}


}

/// @nodoc
abstract mixin class _$SudokuStateCopyWith<$Res> implements $SudokuStateCopyWith<$Res> {
  factory _$SudokuStateCopyWith(_SudokuState value, $Res Function(_SudokuState) _then) = __$SudokuStateCopyWithImpl;
@override @useResult
$Res call({
 DateTime day, SudokuPuzzle? puzzle, List<int> grid, List<Set<int>> notes, int? selectedIndex, bool notesMode, SudokuStatus status, DateTime? startedAt, int? hintFlashIndex, int? rejectFlashIndex, Set<int> unitFlashIndices, Set<String> celebratedUnitIds, bool finished, int? points, int? timeSeconds, bool? improved, ResultsArgs? resultsExtra
});




}
/// @nodoc
class __$SudokuStateCopyWithImpl<$Res>
    implements _$SudokuStateCopyWith<$Res> {
  __$SudokuStateCopyWithImpl(this._self, this._then);

  final _SudokuState _self;
  final $Res Function(_SudokuState) _then;

/// Create a copy of SudokuState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? day = null,Object? puzzle = freezed,Object? grid = null,Object? notes = null,Object? selectedIndex = freezed,Object? notesMode = null,Object? status = null,Object? startedAt = freezed,Object? hintFlashIndex = freezed,Object? rejectFlashIndex = freezed,Object? unitFlashIndices = null,Object? celebratedUnitIds = null,Object? finished = null,Object? points = freezed,Object? timeSeconds = freezed,Object? improved = freezed,Object? resultsExtra = freezed,}) {
  return _then(_SudokuState(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime,puzzle: freezed == puzzle ? _self.puzzle : puzzle // ignore: cast_nullable_to_non_nullable
as SudokuPuzzle?,grid: null == grid ? _self._grid : grid // ignore: cast_nullable_to_non_nullable
as List<int>,notes: null == notes ? _self._notes : notes // ignore: cast_nullable_to_non_nullable
as List<Set<int>>,selectedIndex: freezed == selectedIndex ? _self.selectedIndex : selectedIndex // ignore: cast_nullable_to_non_nullable
as int?,notesMode: null == notesMode ? _self.notesMode : notesMode // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SudokuStatus,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,hintFlashIndex: freezed == hintFlashIndex ? _self.hintFlashIndex : hintFlashIndex // ignore: cast_nullable_to_non_nullable
as int?,rejectFlashIndex: freezed == rejectFlashIndex ? _self.rejectFlashIndex : rejectFlashIndex // ignore: cast_nullable_to_non_nullable
as int?,unitFlashIndices: null == unitFlashIndices ? _self._unitFlashIndices : unitFlashIndices // ignore: cast_nullable_to_non_nullable
as Set<int>,celebratedUnitIds: null == celebratedUnitIds ? _self._celebratedUnitIds : celebratedUnitIds // ignore: cast_nullable_to_non_nullable
as Set<String>,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,points: freezed == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int?,timeSeconds: freezed == timeSeconds ? _self.timeSeconds : timeSeconds // ignore: cast_nullable_to_non_nullable
as int?,improved: freezed == improved ? _self.improved : improved // ignore: cast_nullable_to_non_nullable
as bool?,resultsExtra: freezed == resultsExtra ? _self.resultsExtra : resultsExtra // ignore: cast_nullable_to_non_nullable
as ResultsArgs?,
  ));
}


}

// dart format on
