import 'package:bloc/bloc.dart';

/// Handles events of one type one at a time, in order, like
/// `bloc_concurrency`'s `sequential()`. Hints use it: each costs time, so a
/// quick second tap must see what the first one revealed.
EventTransformer<E> sequential<E>() =>
    (events, mapper) => events.asyncExpand(mapper);
