// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'zip_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ZipEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ZipEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ZipEvent()';
}


}

/// @nodoc
class $ZipEventCopyWith<$Res>  {
$ZipEventCopyWith(ZipEvent _, $Res Function(ZipEvent) __);
}


/// Adds pattern-matching-related methods to [ZipEvent].
extension ZipEventPatterns on ZipEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ZipStarted value)?  started,TResult Function( ZipPathChanged value)?  pathChanged,TResult Function( ZipCompleted value)?  completed,TResult Function( ZipHint value)?  hint,TResult Function( ZipReset value)?  reset,TResult Function( ZipPauseRun value)?  pauseRun,TResult Function( ZipResumeRun value)?  resumeRun,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ZipStarted() when started != null:
return started(_that);case ZipPathChanged() when pathChanged != null:
return pathChanged(_that);case ZipCompleted() when completed != null:
return completed(_that);case ZipHint() when hint != null:
return hint(_that);case ZipReset() when reset != null:
return reset(_that);case ZipPauseRun() when pauseRun != null:
return pauseRun(_that);case ZipResumeRun() when resumeRun != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ZipStarted value)  started,required TResult Function( ZipPathChanged value)  pathChanged,required TResult Function( ZipCompleted value)  completed,required TResult Function( ZipHint value)  hint,required TResult Function( ZipReset value)  reset,required TResult Function( ZipPauseRun value)  pauseRun,required TResult Function( ZipResumeRun value)  resumeRun,}){
final _that = this;
switch (_that) {
case ZipStarted():
return started(_that);case ZipPathChanged():
return pathChanged(_that);case ZipCompleted():
return completed(_that);case ZipHint():
return hint(_that);case ZipReset():
return reset(_that);case ZipPauseRun():
return pauseRun(_that);case ZipResumeRun():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ZipStarted value)?  started,TResult? Function( ZipPathChanged value)?  pathChanged,TResult? Function( ZipCompleted value)?  completed,TResult? Function( ZipHint value)?  hint,TResult? Function( ZipReset value)?  reset,TResult? Function( ZipPauseRun value)?  pauseRun,TResult? Function( ZipResumeRun value)?  resumeRun,}){
final _that = this;
switch (_that) {
case ZipStarted() when started != null:
return started(_that);case ZipPathChanged() when pathChanged != null:
return pathChanged(_that);case ZipCompleted() when completed != null:
return completed(_that);case ZipHint() when hint != null:
return hint(_that);case ZipReset() when reset != null:
return reset(_that);case ZipPauseRun() when pauseRun != null:
return pauseRun(_that);case ZipResumeRun() when resumeRun != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( DateTime? date)?  started,TResult Function( List<Cell> path)?  pathChanged,TResult Function()?  completed,TResult Function( int hintsRemaining)?  hint,TResult Function()?  reset,TResult Function()?  pauseRun,TResult Function()?  resumeRun,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ZipStarted() when started != null:
return started(_that.date);case ZipPathChanged() when pathChanged != null:
return pathChanged(_that.path);case ZipCompleted() when completed != null:
return completed();case ZipHint() when hint != null:
return hint(_that.hintsRemaining);case ZipReset() when reset != null:
return reset();case ZipPauseRun() when pauseRun != null:
return pauseRun();case ZipResumeRun() when resumeRun != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( DateTime? date)  started,required TResult Function( List<Cell> path)  pathChanged,required TResult Function()  completed,required TResult Function( int hintsRemaining)  hint,required TResult Function()  reset,required TResult Function()  pauseRun,required TResult Function()  resumeRun,}) {final _that = this;
switch (_that) {
case ZipStarted():
return started(_that.date);case ZipPathChanged():
return pathChanged(_that.path);case ZipCompleted():
return completed();case ZipHint():
return hint(_that.hintsRemaining);case ZipReset():
return reset();case ZipPauseRun():
return pauseRun();case ZipResumeRun():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( DateTime? date)?  started,TResult? Function( List<Cell> path)?  pathChanged,TResult? Function()?  completed,TResult? Function( int hintsRemaining)?  hint,TResult? Function()?  reset,TResult? Function()?  pauseRun,TResult? Function()?  resumeRun,}) {final _that = this;
switch (_that) {
case ZipStarted() when started != null:
return started(_that.date);case ZipPathChanged() when pathChanged != null:
return pathChanged(_that.path);case ZipCompleted() when completed != null:
return completed();case ZipHint() when hint != null:
return hint(_that.hintsRemaining);case ZipReset() when reset != null:
return reset();case ZipPauseRun() when pauseRun != null:
return pauseRun();case ZipResumeRun() when resumeRun != null:
return resumeRun();case _:
  return null;

}
}

}

/// @nodoc


class ZipStarted implements ZipEvent {
  const ZipStarted({this.date});
  

 final  DateTime? date;

/// Create a copy of ZipEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ZipStartedCopyWith<ZipStarted> get copyWith => _$ZipStartedCopyWithImpl<ZipStarted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ZipStarted&&(identical(other.date, date) || other.date == date));
}


@override
int get hashCode => Object.hash(runtimeType,date);

@override
String toString() {
  return 'ZipEvent.started(date: $date)';
}


}

/// @nodoc
abstract mixin class $ZipStartedCopyWith<$Res> implements $ZipEventCopyWith<$Res> {
  factory $ZipStartedCopyWith(ZipStarted value, $Res Function(ZipStarted) _then) = _$ZipStartedCopyWithImpl;
@useResult
$Res call({
 DateTime? date
});




}
/// @nodoc
class _$ZipStartedCopyWithImpl<$Res>
    implements $ZipStartedCopyWith<$Res> {
  _$ZipStartedCopyWithImpl(this._self, this._then);

  final ZipStarted _self;
  final $Res Function(ZipStarted) _then;

/// Create a copy of ZipEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? date = freezed,}) {
  return _then(ZipStarted(
date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc


class ZipPathChanged implements ZipEvent {
  const ZipPathChanged({required final  List<Cell> path}): _path = path;
  

 final  List<Cell> _path;
 List<Cell> get path {
  if (_path is EqualUnmodifiableListView) return _path;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_path);
}


/// Create a copy of ZipEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ZipPathChangedCopyWith<ZipPathChanged> get copyWith => _$ZipPathChangedCopyWithImpl<ZipPathChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ZipPathChanged&&const DeepCollectionEquality().equals(other._path, _path));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_path));

@override
String toString() {
  return 'ZipEvent.pathChanged(path: $path)';
}


}

/// @nodoc
abstract mixin class $ZipPathChangedCopyWith<$Res> implements $ZipEventCopyWith<$Res> {
  factory $ZipPathChangedCopyWith(ZipPathChanged value, $Res Function(ZipPathChanged) _then) = _$ZipPathChangedCopyWithImpl;
@useResult
$Res call({
 List<Cell> path
});




}
/// @nodoc
class _$ZipPathChangedCopyWithImpl<$Res>
    implements $ZipPathChangedCopyWith<$Res> {
  _$ZipPathChangedCopyWithImpl(this._self, this._then);

  final ZipPathChanged _self;
  final $Res Function(ZipPathChanged) _then;

/// Create a copy of ZipEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(ZipPathChanged(
path: null == path ? _self._path : path // ignore: cast_nullable_to_non_nullable
as List<Cell>,
  ));
}


}

/// @nodoc


class ZipCompleted implements ZipEvent {
  const ZipCompleted();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ZipCompleted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ZipEvent.completed()';
}


}




/// @nodoc


class ZipHint implements ZipEvent {
  const ZipHint({required this.hintsRemaining});
  

 final  int hintsRemaining;

/// Create a copy of ZipEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ZipHintCopyWith<ZipHint> get copyWith => _$ZipHintCopyWithImpl<ZipHint>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ZipHint&&(identical(other.hintsRemaining, hintsRemaining) || other.hintsRemaining == hintsRemaining));
}


@override
int get hashCode => Object.hash(runtimeType,hintsRemaining);

@override
String toString() {
  return 'ZipEvent.hint(hintsRemaining: $hintsRemaining)';
}


}

/// @nodoc
abstract mixin class $ZipHintCopyWith<$Res> implements $ZipEventCopyWith<$Res> {
  factory $ZipHintCopyWith(ZipHint value, $Res Function(ZipHint) _then) = _$ZipHintCopyWithImpl;
@useResult
$Res call({
 int hintsRemaining
});




}
/// @nodoc
class _$ZipHintCopyWithImpl<$Res>
    implements $ZipHintCopyWith<$Res> {
  _$ZipHintCopyWithImpl(this._self, this._then);

  final ZipHint _self;
  final $Res Function(ZipHint) _then;

/// Create a copy of ZipEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? hintsRemaining = null,}) {
  return _then(ZipHint(
hintsRemaining: null == hintsRemaining ? _self.hintsRemaining : hintsRemaining // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ZipReset implements ZipEvent {
  const ZipReset();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ZipReset);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ZipEvent.reset()';
}


}




/// @nodoc


class ZipPauseRun implements ZipEvent {
  const ZipPauseRun();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ZipPauseRun);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ZipEvent.pauseRun()';
}


}




/// @nodoc


class ZipResumeRun implements ZipEvent {
  const ZipResumeRun();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ZipResumeRun);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ZipEvent.resumeRun()';
}


}




// dart format on
