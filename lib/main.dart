import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Surimon',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'S'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class PortData {
  SerialPort? port;

  Stream get data => _dataController.stream;

  final _dataController = StreamController();

  Uint8List _data = Uint8List.fromList([]);

  String? address;
  Timer? _timer;
  int _delay = 0;
  int _parity = SerialPortParity.none;

  setPort(String? p) {
    if (p == null && address != null) {
      p = address;
    }
    if (p == null) {
      return;
    }
    if (port != null) {
      port?.close();
      port?.dispose();
    }
    address = p;

    try {
      port = SerialPort(p);
    } on SerialPortError catch (e) {
      return;
    }

    if (port == null) {
      return;
    }

    // We created the port, so cancel timer if it was active
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }

    SerialPortReader reader = SerialPortReader(
      port!,
      timeout: 10000,
    );

    try {
      port!.openReadWrite();
    } on SerialPortError catch (e) {
    }

    SerialPortConfig config = port!.config;
    config.baudRate = 115200;
    config.parity = _parity;
    port!.config = config;

    try {
      reader.stream.handleError((err) {
        // maybe disconnection ?
        //save the port, close and dispose
        reader.close();
        port?.close();
        port?.dispose();
      });
    } catch (e) {
    }


    var readerSubscription = reader.stream.listen((data) {
      BytesBuilder b = BytesBuilder();
      b.add(_data);
      b.add(data);
      _data = b.toBytes();
      _dataController.add(_data);
    }, onError: (error) {
      if (error is SerialPortError) {
        reader.close();
        port?.close();
        port?.dispose();
        port = null;

        if (address != null) {
          _timer = Timer.periodic(const Duration(seconds: 1), retry);
        }
      }
    });
  }

  // TODO add a command buffer to access with up arrow
  retry(Timer timer) {
    setPort(null);
  }

  send(String r) {
    if (port != null) {
      r = r + "\r\n";
      if (_delay > 0) {
        for (final (index, item) in r.codeUnits.indexed) {
          Timer(Duration(milliseconds: _delay * index), () {
            port!.write(Uint8List.fromList([item]));
          });
        }
      }
    }
  }

  setDelay(String val) {
    _delay = int.parse(val);
  }

  setSpeed(int? speed) {
    if (port != null && speed != null) {
      SerialPortConfig config = port!.config;
      config.baudRate = speed;
      port!.config = config;
    }
  }

  setParity(int? parity) {
    if (port != null && parity != null) {
      _parity = parity;
      SerialPortConfig config = port!.config;
      config.parity = parity;
      port!.config = config;
    }
  }
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  List<String> ports = SerialPort.availablePorts;

  final FocusNode inputFocusNode = FocusNode();

  final PortData portData = PortData();
  TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final String text = _controller.text.toLowerCase();
      _controller.value = _controller.value.copyWith(
        text: text,
        selection:
            TextSelection(baseOffset: text.length, extentOffset: text.length),
        composing: TextRange.empty,
      );
    });
    // defines a timer
    Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() {
        ports = SerialPort.availablePorts;
      });
    });
  }

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.

    List<DropdownMenuEntry<String>> ports = SerialPort.availablePorts
        .map((p) => DropdownMenuEntry(value: p, label: p))
        .toList();

    List<DropdownMenuEntry<int>> speeds = [
      300,
      600,
      1200,
      2400,
      4800,
      9600,
      19200,
      28800,
      38400,
      57600,
      76800,
      115200,
      230400
    ].map((p) => DropdownMenuEntry(value: p, label: p.toString())).toList();

    List<DropdownMenuEntry<int>> parities = [
      SerialPortParity.even,
      SerialPortParity.odd,
      SerialPortParity.none,
    ].map((p) {
      String label = "None";
      switch (p) {
        case SerialPortParity.odd:
          label = 'Odd';
          break;
        case SerialPortParity.even:
          label = 'Even';
          break;
      }
      return DropdownMenuEntry(value: p, label: label);
    }).toList();

    if (ports.isEmpty) {
      ports = [
        DropdownMenuEntry(value: "no port", label: "no port", enabled: false)
      ];
    }

    return Scaffold(
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(padding: EdgeInsets.all(16.0),
            child:
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                DropdownMenu(
                  dropdownMenuEntries: ports,
                  label: Text("Serial port"),
                  initialSelection: portData.address,
                  onSelected: (String? port) {
                    setState(() {
                      if (port != null) {
                        portData.setPort(port);
                      }
                    });
                  },
                ),
                DropdownMenu(
                  dropdownMenuEntries: speeds,
                  label: Text("Speed"),
                  onSelected: (int? speed) {
                    setState(() {
                      portData.setSpeed(speed);
                    });
                  },
                ),
                DropdownMenu(
                  dropdownMenuEntries: parities,
                  label: Text("Parity"),
                  onSelected: (int? parity) {
                    setState(() {
                      portData.setParity(parity);
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'char delay (ms)',
                      labelText: 'char delay (ms)',
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (String val) {
                      portData.setDelay(val);
                    },
                  ),
                ),
              ],
            ),
            ),
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                reverse: true,
                scrollDirection: Axis.vertical,
                child: StreamBuilder(
                    stream: portData.data,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Padding(
                            padding: EdgeInsets.all(16.0),
                            child: SelectableText(
                              '\r\n${String.fromCharCodes(snapshot.data).replaceAll("\r\n", "\n").replaceAll("\r", "\n")}',
                              //String.fromCharCodes(snapshot.data),
                              style: TextStyle(fontSize: 18),
                              textAlign: TextAlign.start,
                            ));
                      } else {
                        if (portData.port == null) {
                          return Text(
                            textAlign: TextAlign.center,
                            "No Serial port connected",
                            style: TextStyle(fontSize: 24),
                          );
                        }
                        return Text(
                          "No data received yet",
                          style: TextStyle(fontSize: 24),
                        );
                      }
                    }),
              ),
            ),
            TextField(
              focusNode: inputFocusNode,
              controller: _controller,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: '',
              ),
              onSubmitted: (String r) {
                portData.send(r);
                _controller.clear();
                inputFocusNode.requestFocus();
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
