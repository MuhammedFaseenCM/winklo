// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'word_match_select_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WordMatchSelectItem {

 WordMatchDeck get deck;/// The deck's local best time; null before a clear.
 int? get bestSeconds;
/// Create a copy of WordMatchSelectItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WordMatchSelectItemCopyWith<WordMatchSelectItem> get copyWith => _$WordMatchSelectItemCopyWithImpl<WordMatchSelectItem>(this as WordMatchSelectItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WordMatchSelectItem&&(identical(other.deck, deck) || other.deck == deck)&&(identical(other.bestSeconds, bestSeconds) || other.bestSeconds == bestSeconds));
}


@override
int get hashCode => Object.hash(runtimeType,deck,bestSeconds);

@override
String toString() {
  return 'WordMatchSelectItem(deck: $deck, bestSeconds: $bestSeconds)';
}


}

/// @nodoc
abstract mixin class $WordMatchSelectItemCopyWith<$Res>  {
  factory $WordMatchSelectItemCopyWith(WordMatchSelectItem value, $Res Function(WordMatchSelectItem) _then) = _$WordMatchSelectItemCopyWithImpl;
@useResult
$Res call({
 WordMatchDeck deck, int? bestSeconds
});




}
/// @nodoc
class _$WordMatchSelectItemCopyWithImpl<$Res>
    implements $WordMatchSelectItemCopyWith<$Res> {
  _$WordMatchSelectItemCopyWithImpl(this._self, this._then);

  final WordMatchSelectItem _self;
  final $Res Function(WordMatchSelectItem) _then;

/// Create a copy of WordMatchSelectItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deck = null,Object? bestSeconds = freezed,}) {
  return _then(_self.copyWith(
deck: null == deck ? _self.deck : deck // ignore: cast_nullable_to_non_nullable
as WordMatchDeck,bestSeconds: freezed == bestSeconds ? _self.bestSeconds : bestSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [WordMatchSelectItem].
extension WordMatchSelectItemPatterns on WordMatchSelectItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WordMatchSelectItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WordMatchSelectItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WordMatchSelectItem value)  $default,){
final _that = this;
switch (_that) {
case _WordMatchSelectItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WordMatchSelectItem value)?  $default,){
final _that = this;
switch (_that) {
case _WordMatchSelectItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WordMatchDeck deck,  int? bestSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WordMatchSelectItem() when $default != null:
return $default(_that.deck,_that.bestSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WordMatchDeck deck,  int? bestSeconds)  $default,) {final _that = this;
switch (_that) {
case _WordMatchSelectItem():
return $default(_that.deck,_that.bestSeconds);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WordMatchDeck deck,  int? bestSeconds)?  $default,) {final _that = this;
switch (_that) {
case _WordMatchSelectItem() when $default != null:
return $default(_that.deck,_that.bestSeconds);case _:
  return null;

}
}

}

/// @nodoc


class _WordMatchSelectItem implements WordMatchSelectItem {
  const _WordMatchSelectItem({required this.deck, this.bestSeconds});
  

@override final  WordMatchDeck deck;
/// The deck's local best time; null before a clear.
@override final  int? bestSeconds;

/// Create a copy of WordMatchSelectItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WordMatchSelectItemCopyWith<_WordMatchSelectItem> get copyWith => __$WordMatchSelectItemCopyWithImpl<_WordMatchSelectItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WordMatchSelectItem&&(identical(other.deck, deck) || other.deck == deck)&&(identical(other.bestSeconds, bestSeconds) || other.bestSeconds == bestSeconds));
}


@override
int get hashCode => Object.hash(runtimeType,deck,bestSeconds);

@override
String toString() {
  return 'WordMatchSelectItem(deck: $deck, bestSeconds: $bestSeconds)';
}


}

/// @nodoc
abstract mixin class _$WordMatchSelectItemCopyWith<$Res> implements $WordMatchSelectItemCopyWith<$Res> {
  factory _$WordMatchSelectItemCopyWith(_WordMatchSelectItem value, $Res Function(_WordMatchSelectItem) _then) = __$WordMatchSelectItemCopyWithImpl;
@override @useResult
$Res call({
 WordMatchDeck deck, int? bestSeconds
});




}
/// @nodoc
class __$WordMatchSelectItemCopyWithImpl<$Res>
    implements _$WordMatchSelectItemCopyWith<$Res> {
  __$WordMatchSelectItemCopyWithImpl(this._self, this._then);

  final _WordMatchSelectItem _self;
  final $Res Function(_WordMatchSelectItem) _then;

/// Create a copy of WordMatchSelectItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deck = null,Object? bestSeconds = freezed,}) {
  return _then(_WordMatchSelectItem(
deck: null == deck ? _self.deck : deck // ignore: cast_nullable_to_non_nullable
as WordMatchDeck,bestSeconds: freezed == bestSeconds ? _self.bestSeconds : bestSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$WordMatchSelectState {

 WordMatchSelectStatus get status; List<WordMatchSelectItem> get items; String? get error;
/// Create a copy of WordMatchSelectState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WordMatchSelectStateCopyWith<WordMatchSelectState> get copyWith => _$WordMatchSelectStateCopyWithImpl<WordMatchSelectState>(this as WordMatchSelectState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WordMatchSelectState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(items),error);

@override
String toString() {
  return 'WordMatchSelectState(status: $status, items: $items, error: $error)';
}


}

/// @nodoc
abstract mixin class $WordMatchSelectStateCopyWith<$Res>  {
  factory $WordMatchSelectStateCopyWith(WordMatchSelectState value, $Res Function(WordMatchSelectState) _then) = _$WordMatchSelectStateCopyWithImpl;
@useResult
$Res call({
 WordMatchSelectStatus status, List<WordMatchSelectItem> items, String? error
});




}
/// @nodoc
class _$WordMatchSelectStateCopyWithImpl<$Res>
    implements $WordMatchSelectStateCopyWith<$Res> {
  _$WordMatchSelectStateCopyWithImpl(this._self, this._then);

  final WordMatchSelectState _self;
  final $Res Function(WordMatchSelectState) _then;

/// Create a copy of WordMatchSelectState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? items = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as WordMatchSelectStatus,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<WordMatchSelectItem>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WordMatchSelectState].
extension WordMatchSelectStatePatterns on WordMatchSelectState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WordMatchSelectState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WordMatchSelectState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WordMatchSelectState value)  $default,){
final _that = this;
switch (_that) {
case _WordMatchSelectState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WordMatchSelectState value)?  $default,){
final _that = this;
switch (_that) {
case _WordMatchSelectState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WordMatchSelectStatus status,  List<WordMatchSelectItem> items,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WordMatchSelectState() when $default != null:
return $default(_that.status,_that.items,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WordMatchSelectStatus status,  List<WordMatchSelectItem> items,  String? error)  $default,) {final _that = this;
switch (_that) {
case _WordMatchSelectState():
return $default(_that.status,_that.items,_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WordMatchSelectStatus status,  List<WordMatchSelectItem> items,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _WordMatchSelectState() when $default != null:
return $default(_that.status,_that.items,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _WordMatchSelectState implements WordMatchSelectState {
  const _WordMatchSelectState({this.status = WordMatchSelectStatus.initial, final  List<WordMatchSelectItem> items = const <WordMatchSelectItem>[], this.error}): _items = items;
  

@override@JsonKey() final  WordMatchSelectStatus status;
 final  List<WordMatchSelectItem> _items;
@override@JsonKey() List<WordMatchSelectItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  String? error;

/// Create a copy of WordMatchSelectState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WordMatchSelectStateCopyWith<_WordMatchSelectState> get copyWith => __$WordMatchSelectStateCopyWithImpl<_WordMatchSelectState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WordMatchSelectState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_items),error);

@override
String toString() {
  return 'WordMatchSelectState(status: $status, items: $items, error: $error)';
}


}

/// @nodoc
abstract mixin class _$WordMatchSelectStateCopyWith<$Res> implements $WordMatchSelectStateCopyWith<$Res> {
  factory _$WordMatchSelectStateCopyWith(_WordMatchSelectState value, $Res Function(_WordMatchSelectState) _then) = __$WordMatchSelectStateCopyWithImpl;
@override @useResult
$Res call({
 WordMatchSelectStatus status, List<WordMatchSelectItem> items, String? error
});




}
/// @nodoc
class __$WordMatchSelectStateCopyWithImpl<$Res>
    implements _$WordMatchSelectStateCopyWith<$Res> {
  __$WordMatchSelectStateCopyWithImpl(this._self, this._then);

  final _WordMatchSelectState _self;
  final $Res Function(_WordMatchSelectState) _then;

/// Create a copy of WordMatchSelectState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? items = null,Object? error = freezed,}) {
  return _then(_WordMatchSelectState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as WordMatchSelectStatus,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<WordMatchSelectItem>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
