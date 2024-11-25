import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linux Proxy Manager',
      theme: ThemeData.dark(useMaterial3: true)
          .copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const ProxyManager(),
    );
  }
}

class ProxyManager extends StatefulWidget {
  const ProxyManager({super.key});

  @override
  _ProxyManagerState createState() => _ProxyManagerState();
}

class _ProxyManagerState extends State<ProxyManager> {
  final TextEditingController _proxyController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  bool _isProxyEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkExistingProxy();
  }

  Future<void> _checkExistingProxy() async {
    try {
      var proxyModeResult = await Process.run(
          'gsettings', ['get', 'org.gnome.system.proxy', 'mode']);
      String proxyMode = proxyModeResult.stdout.trim().replaceAll("'", "");

      if (proxyMode == 'manual') {
        // Fetch HTTP Proxy
        // var httpProxyHostResult = await Process.run(
        //     'gsettings', ['get', 'org.gnome.system.proxy.http', 'host']);
        // var httpProxyPortResult = await Process.run(
        //     'gsettings', ['get', 'org.gnome.system.proxy.http', 'port']);
        // String httpProxy =
        //     "${httpProxyHostResult.stdout.trim().replaceAll("'", "")}:${httpProxyPortResult.stdout.trim()}";

        // Fetch HTTPS Proxy
        var httpsProxyHostResult = await Process.run(
            'gsettings', ['get', 'org.gnome.system.proxy.https', 'host']);
        var httpsProxyPortResult = await Process.run(
            'gsettings', ['get', 'org.gnome.system.proxy.https', 'port']);
        String httpsProxy =
            "${httpsProxyHostResult.stdout.trim().replaceAll("'", "")}:${httpsProxyPortResult.stdout.trim()}";
        if (httpsProxy.isNotEmpty) {
          setState(() {
            _proxyController.text = httpsProxy.split(':')[0];
            _portController.text = httpsProxy.split(':')[1];
            _isProxyEnabled = true;
          });
        }
      } else {
        // setState(() {
        //   _httpProxyController.clear();
        //   _httpsProxyController.clear();
        //   _isProxyEnabled = false;
        // });
      }
    } catch (e) {
      print("Error checking proxy: $e");
    }
  }

  Future<void> _setProxy() async {
    String proxy = _proxyController.text;
    String port = _portController.text;
    if (proxy.isEmpty || port.isEmpty) {
      _showMessage('Proxy and Port cannot be empty.');
      return;
    }

    try {
      await Process.run('bash', [
        '-c',
        "echo 'http_proxy=http://$proxy:$port/' | sudo tee -a /etc/environment && echo 'https_proxy=https://$proxy:$port/' | sudo tee -a /etc/environment"
      ]);

      await Process.run(
          'gsettings', ['set', 'org.gnome.system.proxy', 'mode', 'manual']);

      await Process.run(
          'gsettings', ['set', 'org.gnome.system.proxy.http', 'host', proxy]);

      await Process.run(
          'gsettings', ['set', 'org.gnome.system.proxy.http', 'port', port]);

      await Process.run(
          'gsettings', ['set', 'org.gnome.system.proxy.https', 'host', proxy]);

      await Process.run(
          'gsettings', ['set', 'org.gnome.system.proxy.https', 'port', port]);
      await _checkExistingProxy();

      _showMessage('Proxy set successfully!');
      setState(() {
        _isProxyEnabled = true;
      });
    } catch (e) {
      _showMessage('Failed to set proxy: $e');
    }
  }

  Future<void> _disableProxy() async {
    _proxyController.clear();
    _portController.clear();
    await _setProxy();
    try {
      await Process.run('bash', [
        '-c',
        "sudo sed -i '/http_proxy/d' /etc/environment && sudo sed -i '/https_proxy/d' /etc/environment"
      ]);

      await Process.run(
          'gsettings', ['set', 'org.gnome.system.proxy', 'mode', 'none']);

      _showMessage('Proxy disabled successfully!');
      setState(() {
        _isProxyEnabled = false;
      });
    } catch (e) {
      _showMessage('Failed to disable proxy: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      body: Center(
        child: Container(
          alignment: Alignment.center,
          width: min(size.width, size.height),
          height: size.height,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _proxyController,
                decoration: InputDecoration(labelText: 'Proxy Address'),
              ),
              TextField(
                controller: _portController,
                decoration: InputDecoration(labelText: 'Port'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FilledButton(
                    onPressed: _setProxy,
                    child: Text('Change Proxy'),
                  ),
                  FilledButton(
                    onPressed: _disableProxy,
                    child: Text('Remove Proxy'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'Proxy Status: ${_isProxyEnabled ? "Enabled" : "Disabled"}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
