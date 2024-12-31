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
        colorScheme: ColorScheme.light(),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.dark(),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MyHomePage(title: 'S'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class PortData {
  SerialPort? port;

  Stream get data => _dataController.stream;

  final _dataController = StreamController();

  Uint8List _data = Uint8List.fromList([]);
  SerialPortReader? reader;
  String? address;
  Timer? _timer;
  int _delay = 0;
  int _parity = SerialPortParity.none;
  int _speed = 115200;
  int _stopBits = 1;
  String? _error;

  setPort(String? p) {
    _error = "Could not connect";
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

    reader = SerialPortReader(
      port!,
      timeout: 10000,
    );

    try {
      port!.openReadWrite();
    } on SerialPortError catch (e) {
      _error = 'Error opening port "${e}"';
    }
    try {
      SerialPortConfig config = port!.config;
      config.baudRate = _speed;
      config.parity = _parity;
      config.stopBits = _stopBits;
      port!.config = config;

    } on SerialPortError catch (e) {
      _error = 'Error setting port config "${e}"';
    }
    
    _error = null;

    reader?.stream.handleError((err) {
      // maybe disconnection ?
      _error = 'Error reading stream "${err}"';
      //save the port, close and dispose
      reader?.close();
      port?.close();
      port?.dispose();
    });


    reader?.stream.listen((data) {
      BytesBuilder b = BytesBuilder();
      b.add(_data);
      b.add(data);
      _data = b.toBytes();
      _dataController.add(_data);
    }, onError: (error) {
      if (error is SerialPortError) {
        reader?.close();
        _error = 'Error reading serial port ${error}';
        port?.close();
        port?.dispose();
        port = null;

        if (address != null) {
          _timer = Timer.periodic(const Duration(seconds: 1), retry);
        }
      }
    });
  }

  close() {
    reader?.close();
    port?.close();
    port?.dispose();
    port = null;
    _error = null;
  }

  // TODO add a command buffer to access with up arrow
  retry(Timer timer) {
    setPort(null);
  }

  send(String r) {
    if (port != null) {
      r = "$r\r\n";
      if (_delay > 0) {
        for (final (index, item) in r.codeUnits.indexed) {
          Timer(Duration(milliseconds: _delay * index), () {
            port!.write(Uint8List.fromList([item]));
          });
        }
      } else {
        port!.write(Uint8List.fromList(r.codeUnits));
      }
    } else {
      _error = "Connect to a serial port first";
      Timer(Duration(seconds: 5), () {
        _error = null;
      });
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
      _speed = speed;
    }
  }

  setStop(int? stop) {
    if (port != null && stop != null) {
      SerialPortConfig config = port!.config;
      config.stopBits = stop;
      port!.config = config;
      _stopBits = stop;
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
  List<String> ports = SerialPort.availablePorts;

  final FocusNode inputFocusNode = FocusNode();

  final PortData portData = PortData();
  TextEditingController _controller = TextEditingController();
  TextEditingController _delayController = TextEditingController();

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
    _delayController = TextEditingController(text: portData._delay.toString());
    // defines a timer
    Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() {
        ports = SerialPort.availablePorts;
      });
    });
  }

  String hexFormat(Uint8List data) {
    return "";
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

    List<DropdownMenuEntry<int>> stopBits = [
      1,
      2,
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
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  DropdownMenu(
                    dropdownMenuEntries: ports,
                    label: Text("Serial port", style: TextStyle(color: portData.port != null ? Color(0xFF00CC11) : Color.fromARGB(255, 204, 0, 51)),),
                    initialSelection: portData.address,
                    onSelected: (String? port) {
                      setState(() {
                        if (port != null) {
                          portData.setPort(port);
                        }
                      });
                    },
                  ),
                  portData.port != null ? 
                  Padding(padding: EdgeInsets.all(2),
                    child: IconButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 1,
                      ),
                      tooltip: "Close connection",
                      onPressed: () {
                        portData.close();
                      },
                      icon: const Icon(Icons.close_rounded),
                    )
                  )
                  :
                  Padding(padding: EdgeInsets.all(2), 
                    child: portData.address != null ? 
                      IconButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 1,
                        ),
                        tooltip: "Connect",
                        onPressed: () {
                          portData.setPort(null);
                        },
                        icon: const Icon(Icons.check_circle),
                      )
                    :
                    Padding(padding: EdgeInsets.all(0))
                  ),
                  DropdownMenu(
                    dropdownMenuEntries: speeds,
                    label: Text("Speed"),
                    initialSelection: portData._speed,
                    onSelected: (int? speed) {
                      setState(() {
                        portData.setSpeed(speed);
                      });
                    },
                  ),
                  Padding(padding: EdgeInsets.all(1)),
                  DropdownMenu(
                    dropdownMenuEntries: parities,
                    label: Text("Parity"),
                    initialSelection: portData._parity,
                    onSelected: (int? parity) {
                      setState(() {
                        portData.setParity(parity);
                      });
                    },
                  ),
                  Padding(padding: EdgeInsets.all(1)),
                  DropdownMenu(
                    dropdownMenuEntries: stopBits,
                    label: Text("Stop"),
                    initialSelection: portData._stopBits,
                    onSelected: (int? stop) {
                      setState(() {
                        portData.setStop(stop);
                      });
                    },
                  ),
                  Padding(padding: EdgeInsets.all(1)),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        label: Text('Char delay (ms)'),
                      ),
                      controller: _delayController,
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
              child: StreamBuilder(
                  stream: portData.data,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return SingleChildScrollView(
                          reverse: true,
                          scrollDirection: Axis.vertical,
                          child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Row(children: [
                                Text("1\r\n2", style: TextStyle(fontSize: 18)),
                              SelectableText(
                                '\r\n${String.fromCharCodes(snapshot.data).replaceAll("\r\n", "\n").replaceAll("\r", "\n")}',
                                //String.fromCharCodes(snapshot.data),
                                style: TextStyle(fontSize: 18),
                                textAlign: TextAlign.start,
                              ),
                              Text(hexFormat(snapshot.data), style: TextStyle(fontSize: 18)),
                              ])));
                    } else if(portData._error != null) {
                      return Center(
                        child:Text(
                          'Serial error: ${portData._error}',
                          style: TextStyle(fontSize: 24, color: Color.fromARGB(255, 247, 33, 108)),
                        
                        )
                      );
                    } else {
                      if (portData.port == null) {
                        return Center(child:Text(
                          textAlign: TextAlign.center,
                          "No Serial port connected",
                          style: TextStyle(fontSize: 24),
                        ));
                      }
                      return Center(child:Text(
                        "No data received yet",
                        style: TextStyle(fontSize: 24),
                      ));
                    }
                  }),
            ),
            TextField(
              focusNode: inputFocusNode,
              controller: _controller,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(0)),
                hintText: '',
                labelText: 'Command input',
              ),
              enabled: portData.port != null,
              onSubmitted: (String r) {
                portData.send(r);
                _controller.clear();
                inputFocusNode.requestFocus();
              },
            ),
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _incrementCounter,
      //   tooltip: 'Increment',
      //   child: const Icon(Icons.add),
      // ),
    );
  }
}
