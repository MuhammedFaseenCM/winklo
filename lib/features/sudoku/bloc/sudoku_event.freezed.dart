// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sudoku_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SudokuEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SudokuEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SudokuEvent()';
}


}

/// @nodoc
class $SudokuEventCopyWith<$Res>  {
$SudokuEventCopyWith(SudokuEvent _, $Res Function(SudokuEvent) __);
}


/// Adds pattern-matching-related methods to [SudokuEvent].
extension SudokuEventPatterns on SudokuEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SudokuStarted value)?  started,TResult Function( SudokuCellSelected value)?  cellSelected,TResult Function( SudokuDigitTapped value)?  digitTapped,TResult Function( SudokuErase value)?  erase,TResult Function( SudokuNotesModeToggled value)?  notesModeToggled,TResult Function( SudokuHint value)?  hint,TResult Function( SudokuDismissHint value)?  dismissHint,TResult Function( SudokuReset value)?  reset,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SudokuStarted() when started != null:
return started(_that);case SudokuCellSelected() when cellSelected != null:
return cellSelected(_that);case SudokuDigitTapped() when digitTapped != null:
return digitTapped(_that);case SudokuErase() when erase != null:
return erase(_that);case SudokuNotesModeToggled() when notesModeToggled != null:
return notesModeToggled(_that);case SudokuHint() when hint != null:
return hint(_that);case SudokuDismissHint() when dismissHint != null:
return dismissHint(_that);case SudokuReset() when reset != null:
return reset(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SudokuStarted value)  started,required TResult Function( SudokuCellSelected value)  cellSelected,required TResult Function( SudokuDigitTapped value)  digitTapped,required TResult Function( SudokuErase value)  erase,required TResult Function( SudokuNotesModeToggled value)  notesModeToggled,required TResult Function( SudokuHint value)  hint,required TResult Function( SudokuDismissHint value)  dismissHint,required TResult Function( SudokuReset value)  reset,}){
final _that = this;
switch (_that) {
case SudokuStarted():
return started(_that);case SudokuCellSelected():
return cellSelected(_that);case SudokuDigitTapped():
return digitTapped(_that);case SudokuErase():
return erase(_that);case SudokuNotesModeToggled():
return notesModeToggled(_that);case SudokuHint():
return hint(_that);case SudokuDismissHint():
return dismissHint(_that);case SudokuReset():
return reset(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SudokuStarted value)?  started,TResult? Function( SudokuCellSelected value)?  cellSelected,TResult? Function( SudokuDigitTapped value)?  digitTapped,TResult? Function( SudokuErase value)?  erase,TResult? Function( SudokuNotesModeToggled value)?  notesModeToggled,TResult? Function( SudokuHint value)?  hint,TResult? Function( SudokuDismissHint value)?  dismissHint,TResult? Function( SudokuReset value)?  reset,}){
final _that = this;
switch (_that) {
case SudokuStarted() when started != null:
return started(_that);case SudokuCellSelected() when cellSelected != null:
return cellSelected(_that);case SudokuDigitTapped() when digitTapped != null:
return digitTapped(_that);case SudokuErase() when erase != null:
return erase(_that);case SudokuNotesModeToggled() when notesModeToggled != null:
return notesModeToggled(_that);case SudokuHint() when hint != null:
return hint(_that);case SudokuDismissHint() when dismissHint != null:
return dismissHint(_that);case SudokuReset() when reset != null:
return reset(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( DateTime? date)?  started,TResult Function( Cell cell)?  cellSelected,TResult Function( int digit)?  digitTapped,TResult Function()?  erase,TResult Function()?  notesModeToggled,TResult Function()?  hint,TResult Function()?  dismissHint,TResult Function()?  reset,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SudokuStarted() when started != null:
return started(_that.date);case SudokuCellSelected() when cellSelected != null:
return cellSelected(_that.cell);case SudokuDigitTapped() when digitTapped != null:
return digitTapped(_that.digit);case SudokuErase() when erase != null:
return erase();case SudokuNotesModeToggled() when notesModeToggled != null:
return notesModeToggled();case SudokuHint() when hint != null:
return hint();case SudokuDismissHint() when dismissHint != null:
return dismissHint();case SudokuReset() when reset != null:
return reset();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( DateTime? date)  started,required TResult Function( Cell cell)  cellSelected,required TResult Function( int digit)  digitTapped,required TResult Function()  erase,required TResult Function()  notesModeToggled,required TResult Function()  hint,required TResult Function()  dismissHint,required TResult Function()  reset,}) {final _that = this;
switch (_that) {
case SudokuStarted():
return started(_that.date);case SudokuCellSelected():
return cellSelected(_that.cell);case SudokuDigitTapped():
return digitTapped(_that.digit);case SudokuErase():
return erase();case SudokuNotesModeToggled():
return notesModeToggled();case SudokuHint():
return hint();case SudokuDismissHint():
return dismissHint();case SudokuReset():
return reset();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( DateTime? date)?  started,TResult? Function( Cell cell)?  cellSelected,TResult? Function( int digit)?  digitTapped,TResult? Function()?  erase,TResult? Function()?  notesModeToggled,TResult? Function()?  hint,TResult? Function()?  dismissHint,TResult? Function()?  reset,}) {final _that = this;
switch (_that) {
case SudokuStarted() when started != null:
return started(_that.date);case SudokuCellSelected() when cellSelected != null:
return cellSelected(_that.cell);case SudokuDigitTapped() when digitTapped != null:
return digitTapped(_that.digit);case SudokuErase() when erase != null:
return erase();case SudokuNotesModeToggled() when notesModeToggled != null:
return notesModeToggled();case SudokuHint() when hint != null:
return hint();case SudokuDismissHint() when dismissHint != null:
return dismissHint();case SudokuReset() when reset != null:
return reset();case _:
  return null;

}
}

}

/// @nodoc


class SudokuStarted implements SudokuEvent {
  const SudokuStarted({this.date});
  

 final  DateTime? date;

/// Create a copy of SudokuEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SudokuStartedCopyWith<SudokuStarted> get copyWith => _$SudokuStartedCopyWithImpl<SudokuStarted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SudokuStarted&&(identical(other.date, date) || other.date == date));
}


@override
int get hashCode => Object.hash(runtimeType,date);

@override
String toString() {
  return 'SudokuEvent.started(date: $date)';
}


}

/// @nodoc
abstract mixin class $SudokuStartedCopyWith<$Res> implements $SudokuEventCopyWith<$Res> {
  factory $SudokuStartedCopyWith(SudokuStarted value, $Res Function(SudokuStarted) _then) = _$SudokuStartedCopyWithImpl;
@useResult
$Res call({
 DateTime? date
});




}
/// @nodoc
class _$SudokuStartedCopyWithImpl<$Res>
    implements $SudokuStartedCopyWith<$Res> {
  _$SudokuStartedCopyWithImpl(this._self, this._then);

  final SudokuStarted _self;
  final $Res Function(SudokuStarted) _then;

/// Create a copy of SudokuEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? date = freezed,}) {
  return _then(SudokuStarted(
date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc


class SudokuCellSelected implements SudokuEvent {
  const SudokuCellSelected(this.cell);
  

 final  Cell cell;

/// Create a copy of SudokuEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SudokuCellSelectedCopyWith<SudokuCellSelected> get copyWith => _$SudokuCellSelectedCopyWithImpl<SudokuCellSelected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SudokuCellSelected&&(identical(other.cell, cell) || other.cell == cell));
}


@override
int get hashCode => Object.hash(runtimeType,cell);

@override
String toString() {
  return 'SudokuEvent.cellSelected(cell: $cell)';
}


}

/// @nodoc
abstract mixin class $SudokuCellSelectedCopyWith<$Res> implements $SudokuEventCopyWith<$Res> {
  factory $SudokuCellSelectedCopyWith(SudokuCellSelected value, $Res Function(SudokuCellSelected) _then) = _$SudokuCellSelectedCopyWithImpl;
@useResult
$Res call({
 Cell cell
});




}
/// @nodoc
class _$SudokuCellSelectedCopyWithImpl<$Res>
    implements $SudokuCellSelectedCopyWith<$Res> {
  _$SudokuCellSelectedCopyWithImpl(this._self, this._then);

  final SudokuCellSelected _self;
  final $Res Function(SudokuCellSelected) _then;

/// Create a copy of SudokuEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? cell = null,}) {
  return _then(SudokuCellSelected(
null == cell ? _self.cell : cell // ignore: cast_nullable_to_non_nullable
as Cell,
  ));
}


}

/// @nodoc


class SudokuDigitTapped implements SudokuEvent {
  const SudokuDigitTapped(this.digit);
  

 final  int digit;

/// Create a copy of SudokuEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SudokuDigitTappedCopyWith<SudokuDigitTapped> get copyWith => _$SudokuDigitTappedCopyWithImpl<SudokuDigitTapped>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SudokuDigitTapped&&(identical(other.digit, digit) || other.digit == digit));
}


@override
int get hashCode => Object.hash(runtimeType,digit);

@override
String toString() {
  return 'SudokuEvent.digitTapped(digit: $digit)';
}


}

/// @nodoc
abstract mixin class $SudokuDigitTappedCopyWith<$Res> implements $SudokuEventCopyWith<$Res> {
  factory $SudokuDigitTappedCopyWith(SudokuDigitTapped value, $Res Function(SudokuDigitTapped) _then) = _$SudokuDigitTappedCopyWithImpl;
@useResult
$Res call({
 int digit
});




}
/// @nodoc
class _$SudokuDigitTappedCopyWithImpl<$Res>
    implements $SudokuDigitTappedCopyWith<$Res> {
  _$SudokuDigitTappedCopyWithImpl(this._self, this._then);

  final SudokuDigitTapped _self;
  final $Res Function(SudokuDigitTapped) _then;

/// Create a copy of SudokuEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? digit = null,}) {
  return _then(SudokuDigitTapped(
null == digit ? _self.digit : digit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class SudokuErase implements SudokuEvent {
  const SudokuErase();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SudokuErase);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SudokuEvent.erase()';
}


}




/// @nodoc


class SudokuNotesModeToggled implements SudokuEvent {
  const SudokuNotesModeToggled();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SudokuNotesModeToggled);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SudokuEvent.notesModeToggled()';
}


}




/// @nodoc


class SudokuHint implements SudokuEvent {
  const SudokuHint();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SudokuHint);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SudokuEvent.hint()';
}


}




/// @nodoc


class SudokuDismissHint implements SudokuEvent {
  const SudokuDismissHint();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SudokuDismissHint);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SudokuEvent.dismissHint()';
}


}




/// @nodoc


class SudokuReset implements SudokuEvent {
  const SudokuReset();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SudokuReset);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SudokuEvent.reset()';
}


}




// dart format on
