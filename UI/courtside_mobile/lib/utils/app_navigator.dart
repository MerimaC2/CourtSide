import 'package:flutter/material.dart';

/// Global navigator key so non-widget code (e.g. providers on 401) can navigate.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Set in main(); invoked by [BaseProvider] when the API returns 401 (session expired).
void Function()? onUnauthorized;
