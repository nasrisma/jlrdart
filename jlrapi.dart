import 'package:uuid/uuid.dart';
import 'data/trip.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';

const String IFAS_BASE_URL = "https://ifas.prod-row.jlrmotor.com/ifas/jlr";
const String IFAS_BASE_HOST = "ifas.prod-row.jlrmotor.com";
const String IFAS_BASE_PATH = "/ifas/jlr";

const String IFOP_BASE_ULR = "https://ifop.prod-row.jlrmotor.com/ifop/jlr";
const String IFOP_BASE_HOST = "ifop.prod-row.jlrmotor.com";
const String IFOP_BASE_PATH = "/ifop/jlr";

const String IF9_BASE_URL  = "https://if9.prod-row.jlrmotor.com/if9/jlr";
const String IF9_BASE_HOST  = "if9.prod-row.jlrmotor.com";
const String IF9_BASE_PATH  = "/if9/jlr";

class Connection {
  // Main credentials
  static String _email;
  static String _password;

  // Global settings
  static String deviceId;
  static String refreshToken;
  static String mainVin;
  static bool metric = true;

  // For all requests
  static String accessToken;
  static DateTime expiration;
  static String authToken;
  static String userId;

  Map<String, String> oauth;

  Future<List<Vehicle>> connect() async {

    print('connect...');
    if (refreshToken != null) {
      // Not handled...TODO: set oauth to refresh and nothing else...
      print('Not supported!');
    }
    if (deviceId == null) {
      var uuid = Uuid();
      deviceId = uuid.v4();
    }
    oauth = {
      "grant_type": "password",
      "username": _email,
      "password": _password
    };

    if (_email == 'demo') {
      List<Vehicle> list = [];
      Vehicle demoCar = Vehicle('', true);
      demoCar.carName = "Mr. Jag (DEMO)";
      demoCar.stateOfCharge = 55;
      demoCar.vehicleStatus = {
        "ODOMETER_METER_RESOLUTION": "true",
        "EV_CHARGING_STATUS": "CHARGING",
        "EV_CHARGING_RATE_KM_PER_HOUR": "28",
        "EV_STATE_OF_CHARGE": "56",
        "EV_IS_PLUGGED_IN" : "UNKNOWN",
        "EV_RANGE_ON_BATTERY_KM": "300.0",
        "EV_RANGE_ON_BATTERY_MILES": "232.0",
        "EV_RANGE_GET_ME_HOMEx10": "200.4",
        // "EV_RANGE_COMFORTx10": "192.7",
        "EV_RANGE_ECOx10" : "196.5",

        "DOOR_IS_ALL_DOORS_LOCKED" : "TRUE",
        "WASHER_FLUID_WARN": "NORMAL",
        "BRAKE_FLUID_WARN": "NORMAL",

        "TYRE_PRESSURE_FRONT_RIGHT": "221",
        "TYRE_PRESSURE_FRONT_LEFT" : "202",
        "TYRE_PRESSURE_REAR_RIGHT" : "203",
        "TYRE_PRESSURE_REAR_LEFT"  : "204",

        "BATTERY_VOLTAGE": "13.11",
        "EV_BATTERY_PRECONDITIONING_STATUS": "UNKNOWN",
        "TU_STATUS_PRIMARY_VOLT": "4.1000000000000005",
        "TU_STATUS_PRIMARY_CHARGE_PERCENT": "70",
        "EXT_KILOMETERS_TO_SERVICE": "19220",

        // VEHICLE_STATE_TYPE = 'KEY_REMOVED'
        "ODOMETER_METER" : "99999000"
      };
      demoCar.vehicleAttributes = {
        "nickname" : "Mr. Jag (Demo Car)",
        "exteriorColorName": "Black",
        "registrationNumber": "XX11111", // DK version
        "country": "DNK",
        "vehicleBrand": "Jaguar",
        "vehicleType": "I-PACE",
        "vehicleTypeCode": "X590",
        "modelYear": "2020",
      };
      list.add(demoCar);
      return list;
    }

    if (Connection.accessToken == null) {
      final response = await _authenticate(oauth);
      final resp = await utf8.decoder.bind(response).join();
      _registerAuth(resp);
      
      await _registerDeviceId();
      await _loginUser();
    }
    final vehicleResponse = await getVehicles();
    final parsed = jsonDecode(vehicleResponse);
    
    List<Vehicle> list = parsed["vehicles"]
      .map<Vehicle>((jsonItem) => Vehicle(
        jsonItem["vin"],
        false
        )).toList();

    Connection.mainVin = list[0]._vin;
    // await list[0].getStatus();
    // await list[0].getAttributes();
    // await list[0].getHealthStatus();
    return list; 
  }

  void setCredentials(String email, String password) {
    if (_email != email || _password != password) {
      _email = email;
      _password = password;
      Connection.accessToken = null;
    }
  }

  Future<HttpClientResponse> _authenticate(Map<String, String> data) async {
    print("_authenticate(...)");
    String _host = IFAS_BASE_HOST;
    String _path = IFAS_BASE_PATH + "/tokens";

    Uri uri = Uri(host: _host, path: _path, scheme: "https", port: 443);
    HttpClient client = new HttpClient();
    client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    HttpClientRequest request = await client.postUrl(uri)
      ..headers.add("Authorization", "Basic YXM6YXNwYXNz")
      ..headers.contentType = ContentType.json
      ..headers.add("X-Device-Id", deviceId)
      ..write(jsonEncode(data));
    HttpClientResponse response = await request.close();
    return response;
  }

  void _registerAuth(String authresponse) {
    final parsed = jsonDecode(authresponse);
    accessToken = parsed["access_token"];
    expiration = DateTime.now().add(Duration(seconds: int.parse(parsed["expires_in"])));
    authToken = parsed["authorization_token"];
    refreshToken = parsed["refresh_token"];
  }

  Future<HttpClientResponse> _registerDeviceId() async {
    final String _host = IFOP_BASE_HOST;
    final String _path = IFOP_BASE_PATH + "/users/" + Uri.encodeFull(_email) + "/clients";
    Uri uri = Uri(host: _host, path: _path, scheme: "https", port: 443);

    Map<String, String> data = {
      "access_token": accessToken,
      "authorization_token": authToken,
      "expires_in": "86400",
      "deviceID": deviceId
    };

    HttpClient client = new HttpClient();
    client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    HttpClientRequest request = await client.postUrl(uri)
      ..headers.add("Authorization", "Bearer " + accessToken)
      ..headers.contentType = ContentType.json
      ..headers.add("X-Device-Id", deviceId)
      ..write(jsonEncode(data));
    HttpClientResponse response = await request.close();
    // final decoded = await utf8.decoder.bind(response).join();
    // print(decoded);
    return response;
  }

  Future<void> _loginUser() async {
    // print("_loginUser");
    final String _host = IF9_BASE_HOST;
    final String _path = IF9_BASE_PATH + "/users/?loginName=" + Uri.encodeFull(_email);
    Uri uri = Uri(host: _host, path: _path, scheme: "https", port: 443);
    HttpClient client = new HttpClient();

    client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    HttpClientRequest request = await client.getUrl(uri)
      ..headers.add("Authorization", "Bearer " + accessToken)
      ..headers.contentType = ContentType.json
      ..headers.add("X-Device-Id", deviceId)
      ..headers.add("Accept", "application/vnd.wirelesscar.ngtp.if9.User-v3+json");
    HttpClientResponse response = await request.close();
    final decoded = await utf8.decoder.bind(response).join();
    final parsed = jsonDecode(decoded);
    userId = parsed["userId"];
  }

  Future<String> getVehicles() async {
    print("getVehicles");
    final String _host = IF9_BASE_HOST;
    final String _path = IF9_BASE_PATH + "/users/" + userId + "/vehicles?primaryOnly=true";
    Uri uri = Uri(host: _host, path: _path, scheme: "https", port: 443);
    HttpClient client = new HttpClient();

    client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    HttpClientRequest request = await client.getUrl(uri)
      ..headers.add("Authorization", "Bearer " + accessToken)
      ..headers.contentType = ContentType.json
      ..headers.add("X-Device-Id", deviceId);
    HttpClientResponse response = await request.close();
    final decoded = await utf8.decoder.bind(response).join();
    print(decoded);
    return decoded;
  }
}

class Vehicle {
  final String _vin;

  String carName = 'not set';
  int stateOfCharge = 0;
  bool demo = false;

  Map<String, String> vehicleStatus;
  Map<String, String> vehicleAttributes;

  Vehicle(this._vin, this.demo);

  /*
    def get_status(self, key=None):
      """Get vehicle status"""
      headers = self.connection.head.copy()
      headers["Accept"] = "application/vnd.ngtp.org.if9.healthstatus-v2+json"
      result = self.get('status', headers)

      if key:
          return {d['key']: d['value'] for d in result['vehicleStatus']}[key]
      return result
  */
  Future<Map<String, String>> getStatus() async {
    print("Vehicle getStatus");
    Uri uri = _createUri("status");
    HttpClient client = new HttpClient();

    if (demo) {
      return vehicleStatus;
    }

    client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    HttpClientRequest request = await client.getUrl(uri)
      ..headers.add("Authorization", "Bearer " + Connection.accessToken)
      ..headers.contentType = ContentType.json
      ..headers.add("X-Device-Id", Connection.deviceId)
      ..headers.add("Accept", "application/vnd.ngtp.org.if9.healthstatus-v2+json");
    HttpClientResponse response = await request.close();
    final decoded = await utf8.decoder.bind(response).join();
    final parsed = jsonDecode(decoded);
    // print(parsed);
    print(parsed["vehicleStatus"]);
    vehicleStatus = {};
    parsed["vehicleStatus"].forEach((keyValuePair) => {
      vehicleStatus[keyValuePair["key"]] = keyValuePair["value"]
    });

    stateOfCharge = int.parse(vehicleStatus["EV_STATE_OF_CHARGE"]);

    if (vehicleStatus["ODOMETER_METER_RESOLUTION"] == "false") {
      Connection.metric = false;
    }
    return vehicleStatus;
  }

  Future<Map<String, String>> getAttributes() async {
    print("getAttributes");
    Uri uri = _createUri("attributes");
    HttpClient client = new HttpClient();

    if (demo) {
      return vehicleAttributes;
    }

    client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    HttpClientRequest request = await client.getUrl(uri)
      ..headers.add("Authorization", "Bearer " + Connection.accessToken)
      ..headers.contentType = ContentType.json
      ..headers.add("X-Device-Id", Connection.deviceId)
      ..headers.add("Accept", "application/vnd.ngtp.org.VehicleAttributes-v3+json");
    HttpClientResponse response = await request.close();
    final decoded = await utf8.decoder.bind(response).join();
    final parsed = jsonDecode(decoded);

    vehicleAttributes = {};
    print(parsed);
    // vehicleAttributes = parsed;
    
    parsed.forEach((k, v) => vehicleAttributes[k] = v.toString()); // keyValuePair["value"].toString());
    print(vehicleAttributes);
    carName = parsed["nickname"];
    return vehicleAttributes;
  }

  /**
   * def get_health_status(self):
        """Get vehicle health status"""
        headers = self.connection.head.copy()
        headers["Accept"] = "application/vnd.wirelesscar.ngtp.if9.ServiceStatus-v4+json"
        headers["Content-Type"] = "application/vnd.wirelesscar.ngtp.if9.StartServiceConfiguration-v3+json; charset=utf-8"

        vhs_data = self._authenticate_vhs()

        return self.post('healthstatus', headers, vhs_data)
   */
  Future<Map<String, String>> getHealthStatus() async {
    print("getHealthStatus");
    Uri uri = _createUri("healthstatus");
    HttpClient client = new HttpClient();

    client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    String vhsData = await _authenticateEmptyPinProtectedService("VHS");
    return {"x": "y"};
    Map<String, String> vhsPostData = {
      "x": "y"
    };

    HttpClientRequest request = await client.getUrl(uri)
      ..headers.add("Authorization", "Bearer " + Connection.accessToken)
      ..headers.add("Content-Type", "application/vnd.wirelesscar.ngtp.if9.StartServiceConfiguration-v3+json; charset=utf-8")
      ..headers.add("X-Device-Id", Connection.deviceId)
      ..headers.add("Accept", "application/vnd.wirelesscar.ngtp.if9.ServiceStatus-v4+json")
      ..write(jsonEncode(vhsPostData));
    HttpClientResponse response = await request.close();
    final decoded = await utf8.decoder.bind(response).join();
    final parsed = jsonDecode(decoded);

    // vehicleAttributes = {};
    print(parsed);
  }

  /*
    def _authenticate_vhs(self):
        """Authenticate to vhs and get token"""
        return self._authenticate_empty_pin_protected_service("VHS")

    def _authenticate_empty_pin_protected_service(self, service_name):
        data = {
            "serviceName": service_name,
            "pin": ""}
        headers = self.connection.head.copy()
        headers["Content-Type"] = "application/vnd.wirelesscar.ngtp.if9.AuthenticateRequest-v2+json; charset=utf-8"

        return self.post("users/%s/authenticate" % self.connection.user_id, headers, data)
   */
  Future<String> _authenticateEmptyPinProtectedService(String serviceName) async {
    print("_authenticateEmptyPinProtectedService");
    final String _host = IF9_BASE_HOST;
    final String _path = IF9_BASE_PATH + "/users/" + Connection.userId + "/authenticate";
    Uri uri = Uri(host: _host, path: _path, scheme: "https", port: 443);
    HttpClient client = new HttpClient();

    client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    Map<String, String> data = {
      "serviceName": serviceName,
      "pin": ""
    };

    // 404 error here...
    HttpClientRequest request = await client.postUrl(uri)
      ..headers.add("Authorization", "Bearer " + Connection.accessToken)
      ..headers.add("Content-Type",  "application/vnd.wirelesscar.ngtp.if9.AuthenticateRequest-v2+json; charset=utf-8")
      ..headers.add("X-Device-Id", Connection.deviceId)
      // ..headers.add("Accept", "application/vnd.wirelesscar.ngtp.if9.ServiceStatus-v4+json")
      ..write(jsonEncode(data));
    HttpClientResponse response = await request.close();
    final decoded = await utf8.decoder.bind(response).join();
    final parsed = jsonDecode(decoded);
    print(parsed);
    return "";
  }

  /**
   * def preconditioning_start(self, target_temp):
        """Start pre-conditioning for specified temperature (celsius)"""
        service_parameters = [{"key": "PRECONDITIONING",
                               "value": "START"},
                              {"key": "TARGET_TEMPERATURE_CELSIUS",
                               "value": "%s" % target_temp}]

        return self._preconditioning_control(service_parameters)
   */
  Future<Map<String, String>> preconditioningStart(int targetTemperatureCelcius) async {
    List serviceParameters = [
      {"key": "PRECONDITIONING","value": "START"},
      {"key": "TARGET_TEMPERATURE_CELSIUS", "value": targetTemperatureCelcius.toString()}
    ];
    Map<String, String> result = await preconditioningControl(serviceParameters);
    return result;
  }

  /**
        def _preconditioning_control(self, service_parameters):
        """Control the climate preconditioning"""
        headers = self.connection.head.copy()
        headers["Accept"] = "application/vnd.wirelesscar.ngtp.if9.ServiceStatus-v5+json"
        headers["Content-Type"] = "application/vnd.wirelesscar.ngtp.if9.PhevService-v1+json; charset=utf-8"

        ecc_data = self.authenticate_ecc()
        ecc_data['serviceParameters'] = service_parameters

        return self.post("preconditioning", headers, ecc_data)
   */
  Future<Map<String, String>> preconditioningControl(List serviceParameters) async {
    print("preconditioningControl");
    Uri uri = _createUri("preconditioning");
    HttpClient client = new HttpClient();
    client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    if (demo) {
      return {};
    }

    // String eccData = await _authenticateEmptyPinProtectedService("ECC");
    Map<String, List> eccData2 = {
      'serviceParameters': serviceParameters
    };

    HttpClientRequest request = await client.postUrl(uri)
      ..headers.add("Authorization", "Bearer " + Connection.accessToken)
      ..headers.add("Content-Type", "application/vnd.wirelesscar.ngtp.if9.PhevService-v1+json; charset=utf-8")
      ..headers.add("X-Device-Id", Connection.deviceId)
      ..headers.add("Accept", "application/vnd.wirelesscar.ngtp.if9.ServiceStatus-v5+json")
      ..write(jsonEncode(eccData2));
    HttpClientResponse response = await request.close();
    final decoded = await utf8.decoder.bind(response).join();
    final parsed = jsonDecode(decoded);

    print(parsed);
    return {};
  }

  /**
  def get_trips(self, count=1000):
        """Get the last 1000 trips associated with vehicle"""
        headers = self.connection.head.copy()
        headers["Accept"] = "application/vnd.ngtp.org.triplist-v2+json"
        return self.get('trips?count=%d' % count, headers)
  */
  Future<List<Trip>> getTrips(int count) async {
    print("getTrips");
    Uri uri = _createUri("trips?count=" + count.toString());
    HttpClient client = new HttpClient();
    client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    if (demo) {
      Trip demoTrip = Trip("42", name: "Demo trip 1");
      demoTrip.tripDetails = {
        "startTime": "2020-01-01T12:00:00+0000",
        "startPosition": {
          "address": "Abbey Rd, Whitley, Coventry CV3 4LF"
        },
        "endPosition": {
          "address": "Dummy end address"
        },
        "totalEcoScore": {
          "score": 78.0,
          "scoreStatus": "VALID"
        },
         "throttleEcoScore":{
            "score": 3.9,
            "scoreStatus": "VALID"
        },
        "speedEcoScore":{
            "score": 3.9,
            "scoreStatus": "VALID"
        },
        "brakeEcoScore":{
            "score": 5.0,
            "scoreStatus": "VALID"
        },
        "averageSpeed": 78.0,
        "averageEnergyConsumption": 3.21,
        "energyRegenerated": 0.8,
        "startOdometer": 123400,
        "distance": 42000
      };
      return [demoTrip];
    }

    HttpClientRequest request = await client.getUrl(uri)
      ..headers.add("Authorization", "Bearer " + Connection.accessToken)
      ..headers.add("Content-Type", "application/json")
      ..headers.add("X-Device-Id", Connection.deviceId)
      ..headers.add("Accept", "application/vnd.ngtp.org.triplist-v2+json");
    HttpClientResponse response = await request.close();
    final decoded = await utf8.decoder.bind(response).join();
    final parsed = jsonDecode(decoded);
    print(parsed["trips"]);

    List<Trip> trips = [];
    parsed["trips"].forEach((trip) => {
      trips.add(
        Trip(trip["id"].toString(),
          name: trip["name"],
          category: trip["category"],
          routeDetails: trip["routeDetails"],
          tripDetails: trip["tripDetails"]
        )
      )
    });
    return trips;
  }

  /**
    def get_trip(self, trip_id):
        """Get info on a specific trip"""
        return self.get('trips/%s/route?pageSize=1000&page=0' % trip_id, self.connection.head)
  */
  Future<Trip> getTrip(String tripId) async {
    print("getTrip");
    Uri uri = _createUri("trips/" + tripId.toString() + "/route/?pagesize=1000page=0");
    HttpClient client = new HttpClient();
    client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    if (demo) {
      return Trip("123", name: "Test trip");
    }

    HttpClientRequest request = await client.getUrl(uri)
      ..headers.add("Authorization", "Bearer " + Connection.accessToken)
      ..headers.add("Content-Type", "application/json")
      ..headers.add("X-Device-Id", Connection.deviceId);
    HttpClientResponse response = await request.close();
    final decoded = await utf8.decoder.bind(response).join();
    final parsed = jsonDecode(decoded);
    print(parsed);
    Trip trip = new Trip(
      parsed["id"],
      name: parsed["name"],
      category: parsed["category"],
      routeDetails: parsed["routeDetails"],
      tripDetails: parsed["tripDetails"],
    );
    return trip;
  }

  Uri _createUri(String command) {
    final String _host = IF9_BASE_HOST;
    final String _path = IF9_BASE_PATH + "/vehicles/" + _vin + "/" + command;
    Uri uri = Uri(host: _host, path: _path, scheme: "https", port: 443);
    return uri;
  }
}