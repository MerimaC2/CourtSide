import '../models/sport.dart';
import 'base_provider.dart';

class SportProvider extends BaseProvider<Sport> {
  SportProvider() : super('sports');

  @override
  Sport fromJson(Map<String, dynamic> json) => Sport.fromJson(json);
}
