import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speed_ometer/components/speedometer.dart';

class DashScreen extends StatefulWidget {
  const DashScreen({this.unit = 'm/s', Key? key}) : super(key: key);

  final String unit;

  @override
  _DashScreenState createState() => _DashScreenState();
}

class _DashScreenState extends State<DashScreen> {
  /// String that the tts will read aloud, Speed + Expanded Unit
  String get speakText {
    String unit;
    switch (widget.unit) {
      case 'km/h':
        unit = 'kilometers per hour';
        break;

      case 'miles/h':
        unit = 'miles per hour';
        break;

      case 'm/s':
      default:
        unit = 'meters per second';
        break;
    }
    return '${convertedVelocity(_velocity)!.toStringAsFixed(2)} $unit';
  }

  /// Utility function to deserialize saved Duration
  Duration _secondsToDuration(int seconds) {
    int minutes = (seconds / 60).floor();
    return Duration(minutes: minutes, seconds: seconds % 60);
  }

  // For velocity Tracking
  /// Geolocator is used to find velocity
  GeolocatorPlatform locator = GeolocatorPlatform.instance;

  /// Stream that emits values when velocity updates
  late StreamController<double?> _velocityUpdatedStreamController;

  /// Current Velocity in m/s
  double? _velocity;


  double? startLatitude;
  double? startLongitude;
  double? distanceInMeters = 0.0;

  /// Highest recorded velocity so far in m/s.
  double? _highestVelocity;

  /// Velocity in m/s to km/hr converter
  double mpstokmph(double mps) => mps * (18 / 5);

  /// Velocity in m/s to miles per hour converter
  double mpstomilesph(double mps) => mps * (85 / 38);

  /// Relevant velocity in chosen unit
  double? convertedVelocity(double? velocity) {
    velocity = velocity ?? _velocity;

    if (widget.unit == 'm/s') {
      return velocity;
    } else if (widget.unit == 'km/h') {
      return mpstokmph(velocity!);
    } else if (widget.unit == 'miles/h') {
      return mpstomilesph(velocity!);
    }
    return velocity;
  }

  int appStartValue = 0;

  @override
  void initState() {
    super.initState();
    // Speedometer functionality. Updates any time velocity chages.
    _velocityUpdatedStreamController = StreamController<double?>();
    locator
        .getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    )
        .listen(
          (Position position) {
        if(appStartValue == 0){
          startLatitude = position.latitude;
          startLongitude = position.longitude;
        }

        appStartValue += 1;

        log("lat: $startLatitude, long:$startLongitude, appStartValue: $appStartValue");
        _onAccelerate(position.speed, startLatitude!, startLongitude!);
      },
    );

    // Set velocities to zero when app opens
    _velocity = 0;
    _highestVelocity = 0.0;
  }

  /// Callback that runs when velocity updates, which in turn updates stream.
  void _onAccelerate(double speed, double startLatitude,
      double startLongitude,) {
    locator.getCurrentPosition().then(
          (Position updatedPosition) {
        log("update lat: ${updatedPosition
            .latitude}, update long:${updatedPosition.longitude}");
        
        ///Get distance in Miter
        getDistanceInMeters(lat1: startLatitude,
          long1: startLongitude,
          lat2: updatedPosition.latitude,
          long2: updatedPosition.longitude,);

        double geoSpeed = (speed + updatedPosition.speed) / 2;

        _velocity = geoSpeed < 1 ? 0 : geoSpeed;
        if (_velocity! > _highestVelocity!) _highestVelocity = _velocity;
        _velocityUpdatedStreamController.add(_velocity);
      },
    );
  }

  void getDistanceInMeters({
    required double lat1,
    required double long1,
    required double lat2,
    required double long2,
  }) {
    double distanceInMeters =
    Geolocator.distanceBetween(lat1, long1, lat2, long2);

    log(distanceInMeters.toString());
    setState(() {
      this.distanceInMeters = distanceInMeters;
    });
  }

  @override
  Widget build(BuildContext context) {
    const double gaugeBegin = 0,
        gaugeEnd = 200;

    return ListView(
      scrollDirection: Axis.vertical,
      children: <Widget>[
        // StreamBuilder updates Speedometer when new velocity recieved
        StreamBuilder<Object?>(
          stream: _velocityUpdatedStreamController.stream,
          builder: (context, snapshot) {
            return Speedometer(
              gaugeBegin: gaugeBegin,
              gaugeEnd: gaugeEnd,
              velocity: convertedVelocity(_velocity),
              maxVelocity: convertedVelocity(_highestVelocity),
              velocityUnit: widget.unit,
            );
          },
        ),
        Text("${distanceInMeters!.toStringAsFixed(2)} metre",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),)
      ],
    );
  }

  @override
  void dispose() {
    // Velocity Stream
    _velocityUpdatedStreamController.close();
    super.dispose();
  }
}
