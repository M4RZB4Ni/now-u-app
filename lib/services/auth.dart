import 'package:app/models/User.dart';

import 'package:app/routes.dart';

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:app/locator.dart';
import 'package:app/services/navigation.dart';
import 'package:app/services/shared_preferences_service.dart';

class AuthError {
  static const unauthorized = "unauthorized";
  static const internal = "internal";
  static const unknown = "unknown";
}

class AuthenticationService {
  final NavigationService _navigationService = locator<NavigationService>();
  final SharedPreferencesService _sharedPreferencesService =
      locator<SharedPreferencesService>();

  User _currentUser;
  User get currentUser => _currentUser;

  // This is not final as it can be changed
  String domainPrefix = "https://api.now-u.com/api/v1/";

  void switchToStagingBranch() {
    domainPrefix = "https://stagingapi.now-u.com/api/v1/";
  }

  Future<bool> isUserLoggedIn() async {
    User user = await _sharedPreferencesService.loadUserFromPrefs();
    if (user != null) {
      await _updateUser(user.getToken());
    }
    return _currentUser != null;
  }

  Future _updateUser(String token) async {
    if (token != null) {
      _currentUser = await getUser(token);
      _sharedPreferencesService.saveUserToPrefs(_currentUser);
    }
  }

  // Generic Reuqest
  // Handle 401 errors
  Future handleAuthRequestErrors(http.Response response) {
    if (response.statusCode == 200) {
      return null;
    } else if (response.statusCode == 401) {
      // Generic reaction to someone being unauthorized is just send them to the login screen
      _navigationService.navigateTo(Routes.login);
      return Future.error(AuthError.unauthorized);
    } else if (response.statusCode == 500) {
      // Generic reaction to someone being unauthorized is just send them to the login screen
      _navigationService.navigateTo('/');
      return Future.error(AuthError.internal);
    }
    return Future.error(AuthError.unknown);
  }

  Future sendSignInWithEmailLink(
      String email, String name, bool acceptNewletter) async {
    try {
      print("email | $email");
      print("name | $name");
      print("nl | $acceptNewletter");
      await http.post(
        domainPrefix + 'users',
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          'email': email,
          'full_name': name,
          'newsletter_signup': acceptNewletter,
        }),
      );
      return true;
    } catch (e) {
      if (e is PlatformException) {
        return e.message;
      }
      return e.toString();
    }
  }

  Future login(String email, String token) async {
    try {
      http.Response response = await http.post(
        domainPrefix + 'users/login',
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'email': email,
          'token': token,
        }),
      );
      User user = await getUser(json.decode(response.body)['data']['token']);

      await _updateUser(user.getToken());
      return _currentUser != null;
    } catch (e) {
      return e.message;
    }
  }

  Future<User> getUser(String token) async {
    http.Response userResponse =
        await http.get(domainPrefix + 'users/me', headers: <String, String>{
      'token': token,
    });
    if (handleAuthRequestErrors(userResponse) != null) {
      return handleAuthRequestErrors(userResponse);
    }
    User u = User.fromJson(json.decode(userResponse.body)["data"]);
    return u;
  }

  Future<User> updateUserDetails(User user) async {
    http.Response response = await http.put(
      domainPrefix + 'users/me',
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'token': user.getToken(),
      },
      body: json.encode(user.getPostAttributes()),
    );
    if (handleAuthRequestErrors(response) != null) {
      return handleAuthRequestErrors(response);
    }
    User u = User.fromJson(json.decode(response.body));
    return u;
  }

  Future<bool> completeAction(int actionId) async {
    try {
      http.Response response = await http.post(
        domainPrefix + 'users/me/actions/$actionId/complete',
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'token': currentUser.getToken(),
        },
      );
      if (response.statusCode != 200) {
        return false;
      }
      User u = User.fromJson(json.decode(response.body)['data']);

      _currentUser.setPoints(u.getPoints());
      _currentUser.setCompletedActions(u.getCompletedActions());

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> starAction(int actionId) async {
    try {
      http.Response response = await http.post(
        domainPrefix + 'users/me/actions/$actionId/favourite',
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'token': currentUser.getToken(),
        },
      );
      if (response.statusCode != 200) {
        return false;
      }
      User u = User.fromJson(json.decode(response.body)['data']);
      _currentUser = _currentUser.copyWith(
        starredActions: u.starredActions,
        points: u.points,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeActionStatus(int actionId) async {
    try {
      http.Response response = await http.delete(
        domainPrefix + 'users/me/actions/$actionId',
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'token': currentUser.getToken(),
        },
      );
      if (response.statusCode != 200) {
        return false;
      }
      User u = User.fromJson(json.decode(response.body)['data']);
      //_currentUser.setPoints(u.getPoints());
      _currentUser = _currentUser.copyWith(
        starredActions: u.getStarredActions(),
        rejectedActions: u.getRejectedActions(),
        completedActions: u.getCompletedActions(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<User> rejectAction(String token, int actionId, String reason) async {
    Map jsonBody = {'reason': reason};
    http.Response response = await http.post(
      domainPrefix + 'users/me/actions/$actionId/reject',
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'token': currentUser.getToken(),
      },
      body: json.encode(jsonBody),
    );
    if (handleAuthRequestErrors(response) != null) {
      return handleAuthRequestErrors(response);
    }
    User u = User.fromJson(json.decode(response.body)['data']);
    return u;
  }

  Future<bool> joinCampaign(int campaignId) async {
    try {
      http.Response response = await http.post(
        domainPrefix + 'users/me/campaigns/$campaignId',
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'token': currentUser.getToken(),
        },
      );
      if (response.statusCode != 200) {
        return false;
      }
      User u = User.fromJson(json.decode(response.body)["data"]);
      _currentUser = _currentUser.copyWith(
        selectedCampaigns: u.getSelectedCampaigns(),
        points: u.getPoints(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> leaveCampaign(int campaignId) async {
    try {
      http.Response response = await http.delete(
        domainPrefix + 'users/me/campaigns/$campaignId',
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'token': currentUser.getToken(),
        },
      );
      if (response.statusCode != 200) {
        return false;
      }
      User u = User.fromJson(json.decode(response.body)["data"]);
      _currentUser = _currentUser.copyWith(
        selectedCampaigns: u.getSelectedCampaigns(),
        points: u.getPoints(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> completeLearningResource(int learningResourceId) async {
    try {
      http.Response response = await http.post(
        domainPrefix + 'users/me/learning_resources/$learningResourceId',
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'token': currentUser.getToken(),
        },
      );
      if (response.statusCode != 200) {
        return false;
      }
      User u = User.fromJson(json.decode(response.body)['data']);
      _currentUser = _currentUser.copyWith(
          completedLearningResources: u.getCompletedLearningResources());
      return true;
    } catch (e) {
      return false;
    }
  }
}
