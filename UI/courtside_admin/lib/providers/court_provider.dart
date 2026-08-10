import '../models/court.dart';
import 'base_provider.dart';

class CourtProvider extends BaseProvider<Court> {
  CourtProvider() : super('courts');

  @override
  Court fromJson(Map<String, dynamic> json) => Court.fromJson(json);
}
