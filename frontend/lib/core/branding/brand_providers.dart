import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tenant_bootstrap.dart';

final tenantBootstrapProvider = Provider<TenantBootstrap>(
  (ref) => throw UnimplementedError('Tenant bootstrap has not been loaded.'),
);
