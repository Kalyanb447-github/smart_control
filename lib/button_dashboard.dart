import 'dart:async';

import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'dart:math';

class ButtonDashboard extends StatefulWidget {
  @override
  _ButtonDashboardState createState() => _ButtonDashboardState();
}

class _ButtonDashboardState extends State<ButtonDashboard> {
  //static String  mainFileLocation;
  // _ButtonDashboardState({String mainFileLocation});
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  File ourTempFile;

  String messageToPublish;
  String location;
  String folderName = 'Smartify';
  String fileName = 'smart_control.txt';
  static String unique_number;
  static String tempUniqueNumber = '';
  List<String> listOfButtonStatusFromShared = [];

  List<String> switchCommendList = ['', '', '', '', '', ''];

  String buttonOneValue;
  String text;
  File ourMainFile;

  String mainFileLocation = '';
  String buttonValue1;
  String buttonValue2;
  String buttonValue3;
  String buttonValue4;
  var internetStatus;
  bool buttonStatus = false;
  String txtReceive;

  @override
  void initState() {
    super.initState();
    internetStatus = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      // Got a new connectivity status!
      if (result.index == 2) {
        // _showDialog(result.index.toString(), result.toString());
        _showDialog('Sorry', 'No internet Connection');
      }
    });
    checkValueExist();

    _connect();
  }

  dispose() {
    super.dispose();

    internetStatus.cancel();
  }

  _showDialog(title, text) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: Text(text),
            actions: <Widget>[
              FlatButton(
                child: Text('Ok'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

  checkValueExist() async {
    final Directory _appDocDir = await getExternalStorageDirectory();
    final Directory _appFile =
        Directory('${_appDocDir.path}/$folderName/$fileName');
    if (await File(_appFile.path).exists()) {
      ourTempFile = File(_appFile.path);
      //text = await ourTempFile.readAsString();
      switchCommendList = await ourTempFile.readAsLines();
      setState(() {
        location = switchCommendList[0];
        unique_number = switchCommendList[1];
      });
    }
  }

  // CustomPopupMenu _selectedChoices = choices[0];
String buttonStatusFromServer='Output Off';
  void processTxtReceive(String temptxtReceive) {
    if (temptxtReceive.isNotEmpty) {
      setState(() {
        // List<String> tempListOfButtonStatus = [];
        // tempListOfButtonStatus = temptxtReceive.split(',');
        // setFinalStatus(tempListOfButtonStatus);
        buttonStatusFromServer=temptxtReceive;
      });
    }
  }

  setFinalStatus(List<String> listOfButtonStatus) async {
    createFileFunction(
        filename: fileName,
        fileData: listOfButtonStatus[0].toString() +
            '\n' +
            listOfButtonStatus[1].toString() +
            '\n' +
            listOfButtonStatus[2].toString() +
            '\n' +
            listOfButtonStatus[3].toString() +
            '\n' +
            listOfButtonStatus[4].toString() +
            '\n' +
            listOfButtonStatus[5].toString());
  }

  createFileFunction({String filename, String fileData}) async {
    final Directory _appDocDir = await getExternalStorageDirectory();
    ourMainFile = File("${_appDocDir.path}/$folderName/$filename");
    mainFileLocation = ourMainFile.path;
    ourMainFile.writeAsString(fileData);
    // text = await ourMainFile.readAsString();
  }

  //@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  String titleBar = 'MQTT';
  static String broker = '68.183.246.170';
  int port = 1883;
  String username = 'zxcvnm!';
  String passwd = 'Servestack@123';
  int _qosValue = 0;
  bool _retainValue = false;
  static Random random = new Random();
  static int randomNumber = random.nextInt(100000); // from 0 upto 9999 included

  static String deviceIdentifier = '${randomNumber}/device';
  mqtt.MqttClient client;
  mqtt.MqttConnectionState connectionState;

  double _temp = 20;
  String con = '';
  StreamSubscription subscription;

  void _connect() async {
    client = mqtt.MqttClient(broker, '');
    client.port = port;
    client.logging(on: true);
    client.keepAlivePeriod = 3000;
    client.onDisconnected = _onDisconnected;
    print(
        '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@');
    final mqtt.MqttConnectMessage connMess = mqtt.MqttConnectMessage()
        .withClientIdentifier('${deviceIdentifier}')
        .startClean() // Non persistent session for testing
        .keepAliveFor(3000)
        .withWillQos(mqtt.MqttQos.atMostOnce);
    print('[MQTT client] MQTT client connecting....');
    client.connectionMessage = connMess;
    try {
      await client.connect(username, passwd);
    } catch (e) {
      print(e);
      _disconnect();
    }

    /// Check if we are connected
    if (client.connectionState == mqtt.MqttConnectionState.connected) {
      print('[MQTT client] connected');
      setState(() {
        connectionState = client.connectionState;
        con = connectionState.toString();
      });
    } else {
      print('[MQTT client] ERROR: MQTT client connection failed - '
          'disconnecting, state is ${client.connectionState}');
      _disconnect();
    }
    // if (client.connectionStatus.state == mqtt.MqttConnectionState.connected) {
    //   print('[MQTT client] connected');
    //   setState(() {
    //     connectionState = client.connectionStatus.state;
    //     con = connectionState.toString();
    //   });
    // } else {
    //   print('[MQTT client] ERROR: MQTT client connection failed - '
    //       'disconnecting, state is ${client.connectionStatus.state}');
    //   _disconnect();
    // }
    subscription = client.updates.listen(_getMessageFromServer);
    _subscribeToTopic('${unique_number}/client');
  }

  void _disconnect() {
    print('[MQTT client] _disconnect()');
    //_removeSharedValue();
    client.disconnect();
    _onDisconnected();
  }

  void _onDisconnected() {
    print('[MQTT client] _onDisconnected');
    setState(() {
      //topics.clear();
      connectionState = client.connectionStatus.state;
      client.disconnect();
      subscription.cancel();
      subscription = null;
    });
    print('[MQTT client] MQTT client disconnected');
  }

  void _subscribeToTopic(String topic) {
    if (connectionState == mqtt.MqttConnectionState.connected) {
      print('[MQTT client] Subscribing to ${topic.trim()}');
      client.subscribe(topic, mqtt.MqttQos.exactlyOnce);
    }
  }

  // void _onMessage(List<mqtt.MqttReceivedMessage> event) {
  //   print(event.length);
  //   final mqtt.MqttPublishMessage recMess =
  //       event[0].payload as mqtt.MqttPublishMessage;
  //   final String message =
  //       mqtt.MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
  //   setState(() {
  //     txtReceive = mqtt.MqttPublishPayload.bytesToStringAsString(
  //         recMess.payload.message);
  //   });
  //   if (txtReceive != null || txtReceive != '') {
  //     processTxtReceive(txtReceive);
  //   }
  // }
    void _getMessageFromServer(List<mqtt.MqttReceivedMessage> event) {
    //

    //
    print(event.length);
    final mqtt.MqttPublishMessage recMess =
        event[0].payload as mqtt.MqttPublishMessage;
    // final String message =
    //     mqtt.MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    setState(() {
      txtReceive = mqtt.MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message);
    });

    if (txtReceive != null || txtReceive != '') {
      processTxtReceive(txtReceive);
    }
  }

  void _sendMessage({String output}) {
    final mqtt.MqttClientPayloadBuilder builder =
        mqtt.MqttClientPayloadBuilder();

    messageToPublish = "[${unique_number}]${output}";
    builder.addString(messageToPublish);
    client.publishMessage(
      // _topicContent,
      '${unique_number}/device',
      mqtt.MqttQos.values[_qosValue],
      builder.payload,
      retain: _retainValue,
    );
    showInSnackBar('Message Sent');
  }

  void showInSnackBar(String value) {
    _scaffoldKey.currentState.showSnackBar(new SnackBar(
        backgroundColor: Colors.transparent,
        duration: Duration(seconds: 1),
        content: new Text(value)));
  }

  String getRequestValue = '';
  Future<String> getClipBoardData() async {
    ClipboardData data = await Clipboard.getData('text/plain');
    return data.text;
  }

  @override
  Widget build(BuildContext context) {
    //  final width = MediaQuery.of(context).size.width;
    //  final height = MediaQuery.of(context).size.height;
    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        // color: Color(0xFF1C6BB0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0D325E),
              const Color(0xFF1C6BB0),
            ],
            begin: const FractionalOffset(0.0, 0.0),
            end: const FractionalOffset(0.0, 1.0),
          ),
        ),
        child: ListView(
          children: <Widget>[
            // AppbarWidget(),
            AppBar(
              elevation: 0,
              title: Text(
                'Smart Control',
                style: TextStyle(
                  fontSize: 24,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              leading: Container(
                child: Padding(
                  padding: const EdgeInsets.only(left: 0.0),
                  child: Center(
                    child: Text(
                      con != '' ? 'Connect' : 'Disconnect',
                      style: TextStyle(
                        color: con != '' ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        Text(
                          //'$location',
                          switchCommendList[0].toString(),
                          style: TextStyle(fontSize: 24, color: Colors.white),
                        ),
                        Text(
                          // '$unique_number',
                          switchCommendList[1].toString(),
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        )
                      ],
                    ),
                  ],
                ),
                SizedBox(
                  height: 120,
                ),
                InkWell(
                  onTap: () {
                    if (buttonStatusFromServer == null || buttonStatusFromServer== "Output Off") {
                      _sendMessage(output: 'OUTPUTON');
                      setState(() {
                        buttonStatusFromServer = 'Output On';
                       
                      });
                    } else {
                      _sendMessage(output: 'OUTPUTOFF');
                      setState(() {
                        buttonStatusFromServer = 'Output off';
                     
                      });
                    }
                  },
                  child: Cardelement(
                     // icon: Icons.lightbulb_outline,
                      image: buttonStatusFromServer == 'Output On' 
                          ? 'assets/icon.png'
                          : 'assets/icon2.png',
                      text: buttonStatusFromServer == 'Output On' ? 'ON' : 'OFF',
                      buttonStatusFromServer: buttonStatusFromServer
                      //  requestValue: listOfButtonStatusFromShared[0],
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Cardelement extends StatefulWidget {
  IconData icon;
  String text;
  String image;
  Function function;
  int status;
  String requestValue;
  int buttonNo;
  String buttonStatusFromServer;
  Cardelement(
      {this.text,
      this.image,
      this.function,
      this.status,
      this.requestValue,
      this.buttonNo,
      this.buttonStatusFromServer,
      this.icon});

  @override
  _CardelementState createState() => _CardelementState();
}
class _CardelementState extends State<Cardelement> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.function,
      child: Container(
        decoration: BoxDecoration(
          //  color: Color(0XFF0D325E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.blue[400],
            width: 2,
          ),
        ),
        height: MediaQuery.of(context).size.height * .4,
        width: MediaQuery.of(context).size.width * .8,
        child: Card(
          color: Color(0XFF0D325E),
          //color:Colors.red,
          elevation: 15,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image(
                    height: 150,
                    width: 150,
                    image: AssetImage(widget.image),
                  ),
                  // Icon(
                  //   widget.icon,
                  //   size: 150,
                  //   color:widget.buttonStatus==true ?Colors.yellow: Colors.white,
                  // ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    widget.text,
                    style: TextStyle(
                        fontSize: 40,
                        color: Colors.white,
                        // color: Color(0xFF5458A7),
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomPopupMenu {
  CustomPopupMenu({this.title, this.icon});
  String title;
  IconData icon;
}
