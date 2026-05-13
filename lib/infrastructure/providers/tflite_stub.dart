// ignore_for_file: camel_case_types
import 'dart:typed_data';

/// Stub class to allow compilation on Web where dart:ffi (used by tflite_flutter) is not available.
class Interpreter {
  static Interpreter fromBuffer(Uint8List buffer, {InterpreterOptions? options}) {
    throw UnimplementedError('TFLite is not supported on Web');
  }
  void allocateTensors() {}
  void run(dynamic input, dynamic output) {}
  void close() {}
  List<Tensor> getInputTensors() => [];
  List<Tensor> getOutputTensors() => [];
  Tensor getInputTensor(int index) => Tensor();
  Tensor getOutputTensor(int index) => Tensor();
}

class InterpreterOptions {
  int threads = 1;
}

class Tensor {
  List<int> shape = [];
  dynamic type;
  String name = '';
}
