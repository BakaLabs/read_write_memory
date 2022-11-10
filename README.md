# read_write_memory
![GitHub](https://img.shields.io/github/license/blueboy-tm/read_write_memory)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/blueboy-tm/read_write_memory)

### Description
The ReadWriteMemory Class is made on Dart for reading and writing to the memory of any process.

## Usage
```dart
ReadWriteMemory rw = ReadWriteMemory();
Process process1 = rw.getProcessByName('name.exe');
Process process2 = rw.getProcessByID(0);
process1.open();
process2.open();
```

## Process Modules
```dart
for (Module module in process.enumProcessModule()){
    print(module);
    print(' path:   ${module.path}')
}

Module module = process.moduleFromName('module name');
print(module.path);
print(module.lpBaseOfDll);
```
## Get Pointer
```dart
process.getPointer(module.lpBaseOfDll, offsets: [0xFF, 0xFC]);
```
## Close Process
```dart
process.close();
```
[AssultCube hack example](./example/read_write_memory_example.dart)