import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class UpdateNotifier<T> extends ChangeNotifier implements ValueListenable<T> {
  UpdateNotifier(this._value);

  @override
  T get value => _value;
  T _value;
  set value(T newValue) {
    _value = newValue;
    notifyListeners();
  }

  @override
  String toString() => '${describeIdentity(this)}($value)';
}
