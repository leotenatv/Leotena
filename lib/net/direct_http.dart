import 'dart:io';

/// HTTP client that ignores the system proxy and reaches the network directly.
///
/// Phone hotspots often install a Windows proxy, or advertise an IPv6 route
/// that never connects. Either one makes playback look like there is no
/// internet while IPv4 still works. IPv4 is tried first; IPv6 is used when
/// IPv4 is missing or refuses the connection.
HttpClient directHttpClient() {
  final io = HttpClient(context: SecurityContext(withTrustedRoots: true));
  io.findProxy = (_) => 'DIRECT';
  io.connectionFactory = directConnection;
  io.connectionTimeout = const Duration(seconds: 20);
  io.badCertificateCallback = (_, __, ___) => false;
  return io;
}

Future<ConnectionTask<Socket>> directConnection(
  Uri uri,
  String? proxyHost,
  int? proxyPort,
) {
  Socket? opened;
  var cancelled = false;
  final future = connectDirect(uri).then((socket) {
    opened = socket;
    if (cancelled) {
      socket.destroy();
      throw const SocketException('Connection attempt cancelled');
    }
    return socket;
  });
  return Future.value(
    ConnectionTask.fromSocket(future, () {
      cancelled = true;
      opened?.destroy();
    }),
  );
}

Future<Socket> connectDirect(Uri uri) async {
  final host = uri.host;
  final port = uri.port == 0 ? (uri.scheme == 'https' ? 443 : 80) : uri.port;
  final addresses = await _candidates(host);
  if (addresses.isEmpty) {
    throw SocketException('Failed host lookup: $host');
  }

  Object? lastError;
  for (final address in addresses) {
    try {
      final plain = await Socket.connect(address, port, timeout: const Duration(seconds: 6));
      if (uri.scheme != 'https') return plain;
      try {
        return await SecureSocket.secure(
          plain,
          host: host,
          context: SecurityContext(withTrustedRoots: true),
        );
      } catch (error) {
        plain.destroy();
        lastError = error;
      }
    } catch (error) {
      lastError = error;
    }
  }
  final error = lastError;
  if (error != null) throw error;
  throw SocketException('Failed to connect: $host');
}

Future<List<InternetAddress>> _candidates(String host) async {
  final literal = InternetAddress.tryParse(host);
  if (literal != null) return [literal];

  final v4 = await _lookup(host, InternetAddressType.IPv4);
  final v6 = await _lookup(host, InternetAddressType.IPv6);
  final ordered = <InternetAddress>[...v4.take(2), ...v6.take(2)];
  if (ordered.isNotEmpty) return ordered;

  try {
    final any = await InternetAddress.lookup(host).timeout(const Duration(seconds: 5));
    return any.take(2).toList();
  } catch (_) {
    return const [];
  }
}

Future<List<InternetAddress>> _lookup(String host, InternetAddressType type) async {
  try {
    return await InternetAddress.lookup(host, type: type).timeout(const Duration(seconds: 5));
  } catch (_) {
    return const [];
  }
}
