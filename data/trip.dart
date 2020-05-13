class Trip {
  final String id;
  final String name;
  final String category;

  Map<String, dynamic> routeDetails;
  Map<String, dynamic> tripDetails;

  Trip(this.id, {this.name, this.category, this.routeDetails, this.tripDetails});
}