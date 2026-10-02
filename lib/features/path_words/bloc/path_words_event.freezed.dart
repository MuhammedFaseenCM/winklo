// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'path_words_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PathWordsEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathWordsEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PathWordsEvent()';
}


}

/// @nodoc
class $PathWordsEventCopyWith<$Res>  {
$PathWordsEventCopyWith(PathWordsEvent _, $Res Function(PathWordsEvent) __);
}


/// Adds pattern-matching-related methods to [PathWordsEvent].
extension PathWordsEventPatterns on PathWordsEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PathWordsStarted value)?  started,TResult Function( PathWordsPointerDown value)?  pointerDown,TResult Function( PathWordsPointerEnter value)?  pointerEnter,TResult Function( PathWordsPointerUp value)?  pointerUp,TResult Function( PathWordsUndo value)?  undo,TResult Function( PathWordsHint value)?  hint,TResult Function( PathWordsReset value)?  reset,TResult Function( PathWordsPauseRun value)?  pauseRun,TResult Function( PathWordsResumeRun value)?  resumeRun,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PathWordsStarted() when started != null:
return started(_that);case PathWordsPointerDown() when pointerDown != null:
return pointerDown(_that);case PathWordsPointerEnter() when pointerEnter != null:
return pointerEnter(_that);case PathWordsPointerUp() when pointerUp != null:
return pointerUp(_that);case PathWordsUndo() when undo != null:
return undo(_that);case PathWordsHint() when hint != null:
return hint(_that);case PathWordsReset() when reset != null:
return reset(_that);case PathWordsPauseRun() when pauseRun != null:
return pauseRun(_that);case PathWordsResumeRun() when resumeRun != null:
return resumeRun(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PathWordsStarted value)  started,required TResult Function( PathWordsPointerDown value)  pointerDown,required TResult Function( PathWordsPointerEnter value)  pointerEnter,required TResult Function( PathWordsPointerUp value)  pointerUp,required TResult Function( PathWordsUndo value)  undo,required TResult Function( PathWordsHint value)  hint,required TResult Function( PathWordsReset value)  reset,required TResult Function( PathWordsPauseRun value)  pauseRun,required TResult Function( PathWordsResumeRun value)  resumeRun,}){
final _that = this;
switch (_that) {
case PathWordsStarted():
return started(_that);case PathWordsPointerDown():
return pointerDown(_that);case PathWordsPointerEnter():
return pointerEnter(_that);case PathWordsPointerUp():
return pointerUp(_that);case PathWordsUndo():
return undo(_that);case PathWordsHint():
return hint(_that);case PathWordsReset():
return reset(_that);case PathWordsPauseRun():
return pauseRun(_that);case PathWordsResumeRun():
return resumeRun(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PathWordsStarted value)?  started,TResult? Function( PathWordsPointerDown value)?  pointerDown,TResult? Function( PathWordsPointerEnter value)?  pointerEnter,TResult? Function( PathWordsPointerUp value)?  pointerUp,TResult? Function( PathWordsUndo value)?  undo,TResult? Function( PathWordsHint value)?  hint,TResult? Function( PathWordsReset value)?  reset,TResult? Function( PathWordsPauseRun value)?  pauseRun,TResult? Function( PathWordsResumeRun value)?  resumeRun,}){
final _that = this;
switch (_that) {
case PathWordsStarted() when started != null:
return started(_that);case PathWordsPointerDown() when pointerDown != null:
return pointerDown(_that);case PathWordsPointerEnter() when pointerEnter != null:
return pointerEnter(_that);case PathWordsPointerUp() when pointerUp != null:
return pointerUp(_that);case PathWordsUndo() when undo != null:
return undo(_that);case PathWordsHint() when hint != null:
return hint(_that);case PathWordsReset() when reset != null:
return reset(_that);case PathWordsPauseRun() when pauseRun != null:
return pauseRun(_that);case PathWordsResumeRun() when resumeRun != null:
return resumeRun(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( DateTime? date)?  started,TResult Function( Cell cell)?  pointerDown,TResult Function( Cell cell)?  pointerEnter,TResult Function()?  pointerUp,TResult Function()?  undo,TResult Function()?  hint,TResult Function()?  reset,TResult Function()?  pauseRun,TResult Function()?  resumeRun,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PathWordsStarted() when started != null:
return started(_that.date);case PathWordsPointerDown() when pointerDown != null:
return pointerDown(_that.cell);case PathWordsPointerEnter() when pointerEnter != null:
return pointerEnter(_that.cell);case PathWordsPointerUp() when pointerUp != null:
return pointerUp();case PathWordsUndo() when undo != null:
return undo();case PathWordsHint() when hint != null:
return hint();case PathWordsReset() when reset != null:
return reset();case PathWordsPauseRun() when pauseRun != null:
return pauseRun();case PathWordsResumeRun() when resumeRun != null:
return resumeRun();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( DateTime? date)  started,required TResult Function( Cell cell)  pointerDown,required TResult Function( Cell cell)  pointerEnter,required TResult Function()  pointerUp,required TResult Function()  undo,required TResult Function()  hint,required TResult Function()  reset,required TResult Function()  pauseRun,required TResult Function()  resumeRun,}) {final _that = this;
switch (_that) {
case PathWordsStarted():
return started(_that.date);case PathWordsPointerDown():
return pointerDown(_that.cell);case PathWordsPointerEnter():
return pointerEnter(_that.cell);case PathWordsPointerUp():
return pointerUp();case PathWordsUndo():
return undo();case PathWordsHint():
return hint();case PathWordsReset():
return reset();case PathWordsPauseRun():
return pauseRun();case PathWordsResumeRun():
return resumeRun();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( DateTime? date)?  started,TResult? Function( Cell cell)?  pointerDown,TResult? Function( Cell cell)?  pointerEnter,TResult? Function()?  pointerUp,TResult? Function()?  undo,TResult? Function()?  hint,TResult? Function()?  reset,TResult? Function()?  pauseRun,TResult? Function()?  resumeRun,}) {final _that = this;
switch (_that) {
case PathWordsStarted() when started != null:
return started(_that.date);case PathWordsPointerDown() when pointerDown != null:
return pointerDown(_that.cell);case PathWordsPointerEnter() when pointerEnter != null:
return pointerEnter(_that.cell);case PathWordsPointerUp() when pointerUp != null:
return pointerUp();case PathWordsUndo() when undo != null:
return undo();case PathWordsHint() when hint != null:
return hint();case PathWordsReset() when reset != null:
return reset();case PathWordsPauseRun() when pauseRun != null:
return pauseRun();case PathWordsResumeRun() when resumeRun != null:
return resumeRun();case _:
  return null;

}
}

}

/// @nodoc


class PathWordsStarted implements PathWordsEvent {
  const PathWordsStarted({this.date});
  

 final  DateTime? date;

/// Create a copy of PathWordsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PathWordsStartedCopyWith<PathWordsStarted> get copyWith => _$PathWordsStartedCopyWithImpl<PathWordsStarted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathWordsStarted&&(identical(other.date, date) || other.date == date));
}


@override
int get hashCode => Object.hash(runtimeType,date);

@override
String toString() {
  return 'PathWordsEvent.started(date: $date)';
}


}

/// @nodoc
abstract mixin class $PathWordsStartedCopyWith<$Res> implements $PathWordsEventCopyWith<$Res> {
  factory $PathWordsStartedCopyWith(PathWordsStarted value, $Res Function(PathWordsStarted) _then) = _$PathWordsStartedCopyWithImpl;
@useResult
$Res call({
 DateTime? date
});




}
/// @nodoc
class _$PathWordsStartedCopyWithImpl<$Res>
    implements $PathWordsStartedCopyWith<$Res> {
  _$PathWordsStartedCopyWithImpl(this._self, this._then);

  final PathWordsStarted _self;
  final $Res Function(PathWordsStarted) _then;

/// Create a copy of PathWordsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? date = freezed,}) {
  return _then(PathWordsStarted(
date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc


class PathWordsPointerDown implements PathWordsEvent {
  const PathWordsPointerDown(this.cell);
  

 final  Cell cell;

/// Create a copy of PathWordsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PathWordsPointerDownCopyWith<PathWordsPointerDown> get copyWith => _$PathWordsPointerDownCopyWithImpl<PathWordsPointerDown>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathWordsPointerDown&&(identical(other.cell, cell) || other.cell == cell));
}


@override
int get hashCode => Object.hash(runtimeType,cell);

@override
String toString() {
  return 'PathWordsEvent.pointerDown(cell: $cell)';
}


}

/// @nodoc
abstract mixin class $PathWordsPointerDownCopyWith<$Res> implements $PathWordsEventCopyWith<$Res> {
  factory $PathWordsPointerDownCopyWith(PathWordsPointerDown value, $Res Function(PathWordsPointerDown) _then) = _$PathWordsPointerDownCopyWithImpl;
@useResult
$Res call({
 Cell cell
});




}
/// @nodoc
class _$PathWordsPointerDownCopyWithImpl<$Res>
    implements $PathWordsPointerDownCopyWith<$Res> {
  _$PathWordsPointerDownCopyWithImpl(this._self, this._then);

  final PathWordsPointerDown _self;
  final $Res Function(PathWordsPointerDown) _then;

/// Create a copy of PathWordsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? cell = null,}) {
  return _then(PathWordsPointerDown(
null == cell ? _self.cell : cell // ignore: cast_nullable_to_non_nullable
as Cell,
  ));
}


}

/// @nodoc


class PathWordsPointerEnter implements PathWordsEvent {
  const PathWordsPointerEnter(this.cell);
  

 final  Cell cell;

/// Create a copy of PathWordsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PathWordsPointerEnterCopyWith<PathWordsPointerEnter> get copyWith => _$PathWordsPointerEnterCopyWithImpl<PathWordsPointerEnter>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathWordsPointerEnter&&(identical(other.cell, cell) || other.cell == cell));
}


@override
int get hashCode => Object.hash(runtimeType,cell);

@override
String toString() {
  return 'PathWordsEvent.pointerEnter(cell: $cell)';
}


}

/// @nodoc
abstract mixin class $PathWordsPointerEnterCopyWith<$Res> implements $PathWordsEventCopyWith<$Res> {
  factory $PathWordsPointerEnterCopyWith(PathWordsPointerEnter value, $Res Function(PathWordsPointerEnter) _then) = _$PathWordsPointerEnterCopyWithImpl;
@useResult
$Res call({
 Cell cell
});




}
/// @nodoc
class _$PathWordsPointerEnterCopyWithImpl<$Res>
    implements $PathWordsPointerEnterCopyWith<$Res> {
  _$PathWordsPointerEnterCopyWithImpl(this._self, this._then);

  final PathWordsPointerEnter _self;
  final $Res Function(PathWordsPointerEnter) _then;

/// Create a copy of PathWordsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? cell = null,}) {
  return _then(PathWordsPointerEnter(
null == cell ? _self.cell : cell // ignore: cast_nullable_to_non_nullable
as Cell,
  ));
}


}

/// @nodoc


class PathWordsPointerUp implements PathWordsEvent {
  const PathWordsPointerUp();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathWordsPointerUp);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PathWordsEvent.pointerUp()';
}


}




/// @nodoc


class PathWordsUndo implements PathWordsEvent {
  const PathWordsUndo();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathWordsUndo);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PathWordsEvent.undo()';
}


}




/// @nodoc


class PathWordsHint implements PathWordsEvent {
  const PathWordsHint();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathWordsHint);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PathWordsEvent.hint()';
}


}




/// @nodoc


class PathWordsReset implements PathWordsEvent {
  const PathWordsReset();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathWordsReset);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PathWordsEvent.reset()';
}


}




/// @nodoc


class PathWordsPauseRun implements PathWordsEvent {
  const PathWordsPauseRun();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathWordsPauseRun);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PathWordsEvent.pauseRun()';
}


}




/// @nodoc


class PathWordsResumeRun implements PathWordsEvent {
  const PathWordsResumeRun();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathWordsResumeRun);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PathWordsEvent.resumeRun()';
}


}




// dart format on
