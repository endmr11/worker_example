import 'dart:math';
import 'dart:async';
import 'dart:collection';

enum WorkerType { process, response }

class PowElement {
  int a;
  int b;

  PowElement({required this.a, required this.b});

  @override
  String toString() {
    return "a: $a b: $b";
  }
}

class QueueElement<T, K> {
  int opCode;
  WorkerType type;
  K? data;
  int hash;
  List<T>? args;
  Function(dynamic value) callback;

  QueueElement({
    required this.opCode,
    required this.data,
    required this.type,
    required this.hash,
    required this.callback,
    this.args,
  });

  @override
  String toString() {
    return "opCode: $opCode data: $data type: $type hash: $hash callback:$callback, args:$args";
  }
}

class Worker {
  final _queue = Queue<QueueElement>();
  final _streamController = StreamController<QueueElement>();

  Stream<QueueElement> get stream => _streamController.stream;

  int get workerLength => _queue.length;

  void addTask(QueueElement task) {
    if (_queue
        .where((e) => e.opCode == task.opCode && e.type == task.type)
        .isNotEmpty) {
      throw "Task Currently In Queue";
    }
    if (task.type != WorkerType.response) {
      _queue.add(task);
    }
    _process(task);
  }

  void _process(QueueElement task) {
    if (_queue.isEmpty) {
      return;
    }
    _streamController.add(task);
  }

  void removeTask(int hash) {
    if (_queue.isNotEmpty) {
      _queue.removeWhere((e) => e.hash == hash);
    }
  }

  QueueElement getProcessWorker(int opCode) => _queue
      .firstWhere((e) => e.opCode == opCode && e.type == WorkerType.process);
}

void main() {
  var worker = Worker();
  worker.stream.listen((task) {
    if (task.type == WorkerType.process) {
      switch (task.opCode) {
        case 1:
          Future.delayed(Duration(seconds: 2)).then((e) {
            var res = QueueElement(
                opCode: task.opCode,
                data: "2 saniye bekletildim",
                type: WorkerType.response,
                hash: task.hash,
                callback: (val) {});
            worker.addTask(res);
            task.callback.call(null);
          });
          break;
        case 2:
          Future.delayed(Duration(seconds: 4)).then((e) {
            var res = QueueElement(
                opCode: task.opCode,
                data: "4 saniye bekletildim",
                type: WorkerType.response,
                hash: task.hash,
                callback: (val) {});
            worker.addTask(res);
            task.callback.call(null);
          });
          break;
        case 3:
          if (task.args is List<PowElement>) {
            var a = task.args as List<PowElement>;
            MockBluetooth.requestPow(a.first.a, a.first.b);
          }
          break;
        default:
          break;
      }
    } else if (task.type == WorkerType.response) {
      print(worker.getProcessWorker(task.hash));
      worker.getProcessWorker(task.hash).callback.call(task.data);
      worker.removeTask(task.hash);
      print(
          "RESPONSE: ${task.toString()}- Worker Length: ${worker.workerLength}");
    }
  });

  // worker.addTask(QueueElement(
  //     opCode: 1,
  //     data: "",
  //     type: WorkerType.PROCESS,
  //     hash: 123,
  //     args: null,
  //     callback: (val) {
  //       print("2 saniye bekletildim callback");
  //     }));
  // worker.addTask(QueueElement(
  //     opCode: 2,
  //     data: "",
  //     type: WorkerType.PROCESS,
  //     hash: 321,
  //     args: null,
  //     callback: (val) {
  //       print("4 saniye bekletildim callback");
  //     }));

  Future<int> requestPow(int a, int b) {
    final completer = Completer<int>();
    StreamSubscription? subs;
    subs ??= MockBluetooth.mockBleNotifyStream.listen((event) {
      print("mockBleNotify ${event.opCode}");
      switch (event.opCode) {
        case 3:
          var res = QueueElement<PowElement, int>(
            opCode: event.opCode,
            data: event.response,
            type: WorkerType.response,
            hash: event.opCode,
            callback: (val) {},
            args: null,
          );
          worker.addTask(res);
          break;
        default:
          break;
      }
    });
    worker.addTask(QueueElement<PowElement, int>(
        opCode: 3,
        data: null,
        type: WorkerType.process,
        hash: 321,
        args: [PowElement(a: 2, b: 2)],
        callback: (val) {
          subs?.cancel();
          subs = null;
          completer.complete(val);
        }));
    return completer.future;
  }

  requestPow(1, 3).then((value) => print("sonuç: $value"));
}

class MockBluetoothResponse {
  int opCode;
  dynamic response;

  MockBluetoothResponse({required this.opCode, this.response});
}

class MockBluetooth {
  static final MockBluetooth _instance = MockBluetooth._internal();

  factory MockBluetooth() => _instance;

  MockBluetooth._internal();

  static final mockBleNotify = StreamController<MockBluetoothResponse>();
  static final mockBleNotifyStream = mockBleNotify.stream;

  static void requestPow(int a, int b) {
    var powRes = pow(a, b).toInt();
    Timer.periodic(Duration(seconds: 1), (timer) {
      mockBleNotify.add(
          MockBluetoothResponse(opCode: Random().nextInt(4), response: powRes));
    });
  }
}