import 'package:flutter/foundation.dart';

class DetailsProvider extends ChangeNotifier {
  String _token = "";
  String _calleeId = "";
  dynamic _offer;
  dynamic _isVideoOn;
  bool _isClosed = false;

  String get token => _token;
  dynamic get offer => _offer;
  dynamic get isVideoOn => _isVideoOn;
  dynamic get calleeId => _calleeId;
  bool get isClosed => _isClosed;

  void updateData(String newtoken) {
    _token = newtoken;
    notifyListeners(); // Notify listeners about data change
  }

  void updateOffer(dynamic newoffer) {
    _offer = newoffer!;
    notifyListeners(); // Notify listeners about data change
  }

  void updateIsVideoOn(dynamic newIsVideoOn) {
    _isVideoOn = newIsVideoOn;
    notifyListeners(); // Notify listeners about data change
  }

  void updateCalleeID(String newcalleeId) {
    _calleeId = newcalleeId;
    notifyListeners(); // Notify listeners about data change
  }

  void updateAppClose(bool isClosedNew) {
    _isClosed = isClosedNew;
    notifyListeners(); // Notify listeners about data change
  }


}