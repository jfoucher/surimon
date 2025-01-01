import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_platform_alert/flutter_platform_alert.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    ColorScheme light = ColorScheme.light();
    Color text = Color(0xFFE4DADA);
    ColorScheme dark = ColorScheme.dark(onSurface: text);

    return MaterialApp(
      title: 'Surimon',
      theme: ThemeData(
        colorScheme: light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: dark,
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

  // TODO refactor this to convert the serial data to the strings only once when the data arrives
  Stream get lines => _linesController.stream;

  Stream get text => _textController.stream;

  final _linesController = StreamController();
  final _textController = StreamController();

  String _text = "";
  String _lines = "";
  int linesCount = 1;
  SerialPortReader? reader;
  String? address;
  Timer? _timer;
  int _delay = 0;
  int _parity = SerialPortParity.none;
  int _speed = 115200;
  int _stopBits = 1;
  String? _error;
  List<String> buffer = [];

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
    } on SerialPortError {
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
      _error = 'Error opening port "$e"';
    }
    try {
      SerialPortConfig config = port!.config;
      config.baudRate = _speed;
      config.parity = _parity;
      config.stopBits = _stopBits;
      port!.config = config;
    } on SerialPortError catch (e) {
      _error = 'Error setting port config "$e"';
    }

    _error = null;

    reader?.stream.handleError((err) {
      // maybe disconnection ?
      _error = 'Error reading stream "$err"';
      //save the port, close and dispose
      reader?.close();
      port?.close();
      port?.dispose();
    });

    reader?.stream.listen((data) {

      String asString = String.fromCharCodes(data).replaceAll("\r\n", "\n").replaceAll("\r", "\n");

      int cnt = '\n'.allMatches(asString).length;
      String l = "";
      for (int i = linesCount; i < linesCount+cnt; i++) {
        l = "$l$i\n";
      }
      _lines += l;
      linesCount += cnt;
      _text = "$_text$asString";
      _linesController.add(_lines);
      _textController.add(_text);

    }, onError: (error) {
      if (error is SerialPortError) {
        reader?.close();
        _error = 'Error reading serial port $error';
        port?.close();
        port?.dispose();
        port = null;

        if (address != null) {
          _timer = Timer.periodic(const Duration(seconds: 1), retry);
        }
      }
    });
  }

  computeLines(Uint8List data, String lines) {
    for (int d in data) {
      if (d == 0x07) {
        //print('bell ${SystemSoundType.values} ok');
        //SystemSound.play(SystemSoundType.alert);
        FlutterPlatformAlert.playAlertSound();
      }
      if (d == 0x0D || d == 0x0A) {
        linesCount++;
        lines += "$linesCount\r\n";
      }
    }
    return lines;
  }

  close() {
    reader?.close();
    port?.close();
    port?.dispose();
    port = null;
    _error = null;
  }

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
      buffer.add(r.replaceAll("\r", "").replaceAll("\n", ""));
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
  final FocusNode listenerFocusNode = FocusNode();

  int bufPtr = 0;
  final PortData portData = PortData();
  final TextEditingController _controller = TextEditingController();
  TextEditingController _delayController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _delayController = TextEditingController(text: portData._delay.toString());
    // defines a timer
    Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() {
        ports = SerialPort.availablePorts;
      });
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
        child: Column(
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
                    label: Text(
                      "Serial port",
                      style: TextStyle(
                          color: portData.port != null
                              ? Color(0xFF00CC11)
                              : Color.fromARGB(255, 204, 0, 51)),
                    ),
                    initialSelection: portData.address,
                    onSelected: (String? port) {
                      setState(() {
                        if (port != null) {
                          portData.setPort(port);
                        }
                      });
                    },
                  ),
                  portData.port != null
                      ? Padding(
                          padding: EdgeInsets.all(2),
                          child: IconButton(
                            style: ElevatedButton.styleFrom(
                              elevation: 1,
                            ),
                            tooltip: "Close connection",
                            onPressed: () {
                              portData.close();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ))
                      : Padding(
                          padding: EdgeInsets.all(2),
                          child: portData.address != null
                              ? IconButton(
                                  style: ElevatedButton.styleFrom(
                                    elevation: 1,
                                  ),
                                  tooltip: "Connect",
                                  onPressed: () {
                                    portData.setPort(null);
                                  },
                                  icon: const Icon(Icons.check_circle),
                                )
                              : Padding(padding: EdgeInsets.all(0))),
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
                child: Builder(builder: (context) {
                  if (portData._error != null) {
                    return Center(
                        child: Text(
                      'Serial error: ${portData._error}',
                      style: TextStyle(
                          fontSize: 24,
                          color: Color.fromARGB(255, 247, 33, 108)),
                    ));
                  }
                  if (portData.port == null) {
                    return Center(
                        child: Text(
                      textAlign: TextAlign.center,
                      "No Serial port connected",
                      style: TextStyle(fontSize: 24),
                    ));
                  }
                  // if (portData._text.isEmpty) {
                  //   return Center(
                  //       child: Text(
                  //     "No data received yet",
                  //     style: TextStyle(fontSize: 24),
                  //   ));
                  // }
                  return SingleChildScrollView(
                    reverse: true,
                    scrollDirection: Axis.vertical,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StreamBuilder(
                                stream: portData.lines,
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Text(snapshot.data,
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontFamily: 'monospace',
                                            color: Theme.of(context)
                                                .disabledColor
                                        )
                                    );
                                  }
                                  return Padding(padding: EdgeInsets.all(8));
                                }),
                            Padding(
                                padding: EdgeInsets.all(8.0),
                            ),
                            Expanded(
                              child: StreamBuilder(
                                  stream: portData.text,
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return SelectableText(
                                        snapshot.data,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontFamily: 'monospace',
                                        ),
                                        textAlign: TextAlign.start,
                                      );
                                    }
                                    return Padding(padding: EdgeInsets.all(8));
                                  }),
                            ),
                          ]),
                    ),
                  );
                })),
            CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                  if (bufPtr > 0) {
                    bufPtr -= 1;
                  }
                  setState(() => _controller.text = portData.buffer[bufPtr]);
                },
                const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                  if (bufPtr < portData.buffer.length-1) {
                    bufPtr += 1;
                    setState(() => _controller.text = portData.buffer[bufPtr]);
                  } else {
                    setState(() => _controller.text = "");
                  }

                },
                LogicalKeySet(
                  LogicalKeyboardKey.control,
                  LogicalKeyboardKey.keyC,
                ): () {
                  print('ctrl-c $bufPtr ${portData.buffer.length}');
                  portData.send("\x03");
                },
              },
              child: Container(
                decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: Theme.of(context).highlightColor)),
                    borderRadius: BorderRadius.zero),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: EditableText(
                    autocorrect: false,
                    controller: _controller,
                    autofocus: true,
                    focusNode: inputFocusNode,
                    showCursor: true,
                    scribbleEnabled: false,
                    style: TextStyle(fontSize: 18),
                    enableInteractiveSelection: true,
                    cursorColor: Theme.of(context).colorScheme.primary,
                    backgroundCursorColor:
                        Theme.of(context).colorScheme.surface,
                    onSubmitted: (val) {
                      portData.send(val);
                      _controller.clear();
                      setState(() {
                        bufPtr = portData.buffer.length;
                      });
                      inputFocusNode.requestFocus();
                    },
                  ),
                ),
              ),
              // )
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: portData._text.isNotEmpty
          ? Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 60),
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    portData._text = "";
                    portData._textController.add("");
                    portData._lines = "";
                    portData._linesController.add("");
                  });
                },
                tooltip: "Clear screen",
                child: Icon(Icons.clear),
              ),
            )
          : Padding(
              padding: EdgeInsets.all(8.0),
            ),
    );
  }
}
