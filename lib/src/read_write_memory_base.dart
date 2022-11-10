// ignore_for_file: non_constant_identifier_names

import 'dart:io';
import 'dart:ffi';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';

final psapi = DynamicLibrary.open('psapi.dll');

int GetProcessImageFileName(
        int hProcess, Pointer<Utf16> lpImageFileName, int nSize) =>
    _GetProcessImageFileNameA(hProcess, lpImageFileName, nSize);

final _GetProcessImageFileNameA = psapi.lookupFunction<
    Uint32 Function(
        IntPtr hProcess, Pointer<Utf16> lpImageFileName, Uint32 nSize),
    int Function(int hProcess, Pointer<Utf16> lpImageFileName,
        int nSize)>('GetProcessImageFileNameW');

int GetModuleInformation(
        int hProcess, int hModule, Pointer<MODULEINFO> lpmodinfo, int cb) =>
    _GetModuleInformation(hProcess, hModule, lpmodinfo, cb);

final _GetModuleInformation = psapi.lookupFunction<
    Int32 Function(
        IntPtr hProcess, IntPtr hModule, Pointer<MODULEINFO>, Uint32 cb),
    int Function(int hProcess, int hModule, Pointer<MODULEINFO> lpmodinfo,
        int cb)>('GetModuleInformation');

class MODULEINFO extends Struct {
  @Uint32()
  external int lpBaseOfDll;
  @Uint32()
  external int SizeOfImage;
  @Uint32()
  external int EntryPoint;
}

class ReadWriteMemoryError implements Exception {
  String cause;
  ReadWriteMemoryError(this.cause);
  @override
  String toString() {
    return cause;
  }
}

class Module {
  String name;
  String path;
  int lpBaseOfDll;
  int SizeOfImage;
  int EntryPoint;
  Module(
      {this.name = '',
      this.path = '',
      this.lpBaseOfDll = -1,
      this.SizeOfImage = -1,
      this.EntryPoint = -1});

  @override
  String toString() {
    return 'Module: name: $name, lpBaseOfDll: $lpBaseOfDll, SizeOfImage: $SizeOfImage, EntryPoint: $EntryPoint';
  }
}

class Process {
  String name;
  int pid;
  int handle;
  String? errorCode;
  Process({this.name = '', this.pid = -1, this.handle = -1, this.errorCode});

  @override
  String toString() {
    return 'Process: name: $name, pid: $pid, windowsHandle: $handle';
  }

  void open() {
    int dwDesiredAccess = (PROCESS_QUERY_INFORMATION |
        PROCESS_VM_OPERATION |
        PROCESS_VM_READ |
        PROCESS_VM_WRITE);
    int bInheritHandle = 0;
    handle = OpenProcess(dwDesiredAccess, bInheritHandle, pid);
    if (handle == 0 || handle == -1) {
      throw ReadWriteMemoryError('Unable to open process $name');
    }
  }

  int close() {
    CloseHandle(handle);
    return getLastError();
  }

  static int getLastError() {
    return GetLastError();
  }

  Module moduleFromName(String name) {
    for (Module module in enumProcessModule()) {
      if (module.name == name) {
        return module;
      }
    }
    throw ReadWriteMemoryError('Module "$name" not found!');
  }

  Iterable<Module> enumProcessModule() sync* {
    final hMods = calloc<HMODULE>(1024);
    final cbNeeded = calloc<DWORD>();
    if (EnumProcessModulesEx(
            handle, hMods, sizeOf<HMODULE>() * 1024, cbNeeded, 0x03) ==
        1) {
      for (var i = 0; i < (cbNeeded.value ~/ sizeOf<HMODULE>()); i++) {
        final hModule = hMods.elementAt(i).value;
        Pointer<MODULEINFO> lpmodinfo = calloc<MODULEINFO>();
        final szModName = wsalloc(MAX_PATH);
        Module module = Module();
        if (GetModuleFileNameEx(handle, hModule, szModName, MAX_PATH) != 0) {
          module.path = szModName.toDartString();
          module.name = module.path.split('\\').last;
        }
        if (GetModuleInformation(
                handle, hModule, lpmodinfo, sizeOf<MODULEINFO>() * 1024) !=
            0) {
          module.lpBaseOfDll = lpmodinfo.ref.lpBaseOfDll;
          module.SizeOfImage = lpmodinfo.ref.SizeOfImage;
          module.EntryPoint = lpmodinfo.ref.EntryPoint;
        }
        yield module;
        free(szModName);
        free(lpmodinfo);
      }
    }

    free(hMods);
    free(cbNeeded);
  }

  int getPointer(int lpBaseAddress, {List<int>? offsets}) {
    int tempAddress = read(lpBaseAddress, sizeOf<Int32>());
    int pointer = 0x0;
    if (offsets != null && offsets.isNotEmpty) {
      for (var offset in offsets) {
        pointer = tempAddress + offset;
        tempAddress = read(pointer, sizeOf<Int32>());
      }
      return pointer;
    } else {
      return lpBaseAddress;
    }
  }

  int read(int lpBaseAddress, num nSize) {
    Pointer<Int32> lpBuffer = calloc<Int32>();
    ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, nSize.toInt(), nullptr);
    free(lpBuffer);
    return lpBuffer.value;
  }

  String readString(int lpBaseAddress, {int byte = 50}) {
    String str = '';
    Pointer<CHAR> char = calloc<CHAR>();
    for (int i = 0; i < byte; i++) {
      ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress + i),
          char, sizeOf<CHAR>(), nullptr);
      if (char.value == 0x0) {
        break;
      }
      str += String.fromCharCode(char.value);
    }
    free(char);
    return str;
  }

  String readChar(int lpBaseAddress) {
    return readString(lpBaseAddress, byte: 1);
  }

  String readUString(int lpBaseAddress, {int byte = 50}) {
    String str = '';
    Pointer<UCHAR> char = calloc<UCHAR>();
    for (int i = 0; i < byte; i++) {
      ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress + i),
          char, sizeOf<UCHAR>(), nullptr);
      if (char.value == 0x0) {
        break;
      }
      str += String.fromCharCode(char.value);
    }
    free(char);
    return str;
  }

  String readUChar(int lpBaseAddress) {
    return readUString(lpBaseAddress, byte: 1);
  }

  double readDouble(int lpBaseAddress) {
    Pointer<DOUBLE> n = calloc<DOUBLE>();
    ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress), n,
        sizeOf<DOUBLE>(), nullptr);
    free(n);
    return n.value;
  }

  double readFloat(int lpBaseAddress) {
    Pointer<FLOAT> n = calloc<FLOAT>();
    ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress), n,
        sizeOf<FLOAT>(), nullptr);
    free(n);
    return n.value;
  }

  int readLong(int lpBaseAddress) {
    Pointer<LONG> n = calloc<LONG>();
    ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress), n,
        sizeOf<LONG>(), nullptr);
    free(n);
    return n.value;
  }

  int readULong(int lpBaseAddress) {
    Pointer<ULONG> n = calloc<ULONG>();
    ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress), n,
        sizeOf<ULONG>(), nullptr);
    free(n);
    return n.value;
  }

  int readLongLong(int lpBaseAddress) {
    Pointer<LONGLONG> n = calloc<LONGLONG>();
    ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress), n,
        sizeOf<LONGLONG>(), nullptr);
    free(n);
    return n.value;
  }

  int readULongLong(int lpBaseAddress) {
    Pointer<ULONGLONG> n = calloc<ULONGLONG>();
    ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress), n,
        sizeOf<ULONGLONG>(), nullptr);
    free(n);
    return n.value;
  }

  int readShort(int lpBaseAddress) {
    Pointer<SHORT> n = calloc<SHORT>();
    ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress), n,
        sizeOf<SHORT>(), nullptr);
    free(n);
    return n.value;
  }

  int readUShort(int lpBaseAddress) {
    Pointer<USHORT> n = calloc<USHORT>();
    ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress), n,
        sizeOf<USHORT>(), nullptr);
    free(n);
    return n.value;
  }

  int readUInt(int lpBaseAddress) {
    Pointer<UINT> n = calloc<UINT>();
    ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress), n,
        sizeOf<UINT>(), nullptr);
    free(n);
    return n.value;
  }

  int readInt(int lpBaseAddress) {
    Pointer<INT> n = calloc<INT>();
    ReadProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress), n,
        sizeOf<INT>(), nullptr);
    free(n);
    return n.value;
  }

  void write(int lpBaseAddress, num nSize, int value) {
    Pointer<Int32> lpBuffer = calloc<Int32>();
    lpBuffer.value = value;
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<Int32>(), nullptr);
    free(lpBuffer);
  }

  void writeString(int lpBaseAddress, String value) {
    Pointer<CHAR> lpBuffer = calloc<CHAR>();
    for (int i = 0; i < value.length; i++) {
      lpBuffer.value = value.codeUnitAt(i);
      WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress + i),
          lpBuffer, sizeOf<CHAR>(), nullptr);
    }
    free(lpBuffer);
  }

  void writeUString(int lpBaseAddress, String value) {
    Pointer<UCHAR> lpBuffer = calloc<UCHAR>();
    for (int i = 0; i < value.length; i++) {
      lpBuffer.value = value.codeUnitAt(i);
      WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress + i),
          lpBuffer, sizeOf<UCHAR>(), nullptr);
    }
    free(lpBuffer);
  }

  void writeChar(int lpBaseAddress, String value) {
    Pointer<CHAR> lpBuffer = calloc<CHAR>();
    lpBuffer.value = value.codeUnitAt(0);
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<CHAR>(), nullptr);
    free(lpBuffer);
  }

  void writeUChar(int lpBaseAddress, String value) {
    Pointer<UCHAR> lpBuffer = calloc<UCHAR>();
    lpBuffer.value = value.codeUnitAt(0);
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<UCHAR>(), nullptr);
    free(lpBuffer);
  }

  void writeInt(int lpBaseAddress, int value) {
    Pointer<INT> lpBuffer = calloc<INT>();
    lpBuffer.value = value;
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<INT>(), nullptr);
    free(lpBuffer);
  }

  void writeUInt(int lpBaseAddress, int value) {
    Pointer<UINT> lpBuffer = calloc<UINT>();
    lpBuffer.value = value;
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<UINT>(), nullptr);
    free(lpBuffer);
  }

  void writeShort(int lpBaseAddress, int value) {
    Pointer<SHORT> lpBuffer = calloc<SHORT>();
    lpBuffer.value = value;
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<SHORT>(), nullptr);
    free(lpBuffer);
  }

  void writeUShort(int lpBaseAddress, int value) {
    Pointer<USHORT> lpBuffer = calloc<USHORT>();
    lpBuffer.value = value;
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<USHORT>(), nullptr);
    free(lpBuffer);
  }

  void writeLong(int lpBaseAddress, int value) {
    Pointer<LONG> lpBuffer = calloc<LONG>();
    lpBuffer.value = value;
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<LONG>(), nullptr);
    free(lpBuffer);
  }

  void writeULong(int lpBaseAddress, int value) {
    Pointer<ULONG> lpBuffer = calloc<ULONG>();
    lpBuffer.value = value;
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<ULONG>(), nullptr);
    free(lpBuffer);
  }

  void writeLongLong(int lpBaseAddress, int value) {
    Pointer<LONGLONG> lpBuffer = calloc<LONGLONG>();
    lpBuffer.value = value;
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<LONGLONG>(), nullptr);
    free(lpBuffer);
  }

  void writeULongLong(int lpBaseAddress, int value) {
    Pointer<ULONGLONG> lpBuffer = calloc<ULONGLONG>();
    lpBuffer.value = value;
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<ULONGLONG>(), nullptr);
    free(lpBuffer);
  }

  void writeFloat(int lpBaseAddress, double value) {
    Pointer<FLOAT> lpBuffer = calloc<FLOAT>();
    lpBuffer.value = value;
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<FLOAT>(), nullptr);
    free(lpBuffer);
  }

  void writeDouble(int lpBaseAddress, double value) {
    Pointer<DOUBLE> lpBuffer = calloc<DOUBLE>();
    lpBuffer.value = value;
    WriteProcessMemory(handle, Pointer<Int32>.fromAddress(lpBaseAddress),
        lpBuffer, sizeOf<DOUBLE>(), nullptr);
    free(lpBuffer);
  }
}

class ReadWriteMemory {
  Process getProcessByName(String name) {
    if (!name.endsWith('.exe')) {
      name += '.exe';
    }
    for (int pid in enumerateProcesses()) {
      final hProcess = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, pid);
      if (hProcess == 0) {
        continue;
      }
      final lpImageFileName = wsalloc(MAX_PATH);
      GetProcessImageFileName(hProcess, lpImageFileName, MAX_PATH);
      String processName = lpImageFileName.toDartString().split('\\').last;
      if (processName == name) {
        return Process(name: processName, pid: pid);
      }
    }
    throw ReadWriteMemoryError('Process "$name" not found!');
  }

  Process getProcessByID(int pid) {
    final hProcess = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, pid);
    if (hProcess == 0) {
      throw ReadWriteMemoryError('Process "$pid" not found!');
    }
    final lpImageFileName = wsalloc(MAX_PATH);
    GetProcessImageFileName(hProcess, lpImageFileName, MAX_PATH);

    String processName = lpImageFileName.toDartString().split('\\').last;
    return Process(name: processName, pid: pid);
  }

  static Set<int> enumerateProcesses() {
    Set<int> process = <int>{};
    final aProcesses = calloc<DWORD>(1024);
    final cbNeeded = calloc<DWORD>();

    if (EnumProcesses(aProcesses, sizeOf<DWORD>() * 1024, cbNeeded) == 0) {
      print('EnumProcesses failed.');
      exit(1);
    }

    final cProcesses = cbNeeded.value ~/ sizeOf<DWORD>();

    for (var i = 0; i < cProcesses; i++) {
      process.add(aProcesses[i]);
    }
    free(aProcesses);
    free(cbNeeded);
    return process;
  }
}
