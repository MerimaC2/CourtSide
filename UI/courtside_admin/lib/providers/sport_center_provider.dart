import '../models/sport_center.dart';
import 'base_provider.dart';

class SportCenterProvider extends BaseProvider<SportCenter> {
  SportCenterProvider() : super('sportcenters');

  @override
  SportCenter fromJson(Map<String, dynamic> json) => SportCenter.fromJson(json);
}
